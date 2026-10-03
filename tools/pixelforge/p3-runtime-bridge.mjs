import net from "node:net";
import { createHash } from "node:crypto";

const PROTOCOL = "pixelforge-runtime-bridge";
const VERSION = 1;
const DEFAULT_HOST = "127.0.0.1";
const DEFAULT_PORT = 36970;
const DEFAULT_ACTION_INTERVAL_MS = 55;

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

function clone(value) {
  return JSON.parse(JSON.stringify(value));
}

function nonEmpty(value, label) {
  if (typeof value !== "string" || value.trim().length === 0)
    throw new TypeError(`${label} must be a non-empty string`);
  return value.trim();
}

class P3JsonlClient {
  #host;
  #port;
  #timeoutMs;
  #connectRetries;
  #retryDelayMs;
  #socket = null;
  #buffer = "";
  #pending = null;
  #tail = Promise.resolve();

  constructor({
    host = DEFAULT_HOST,
    port = DEFAULT_PORT,
    timeoutMs = 5_000,
    connectRetries = 0,
    retryDelayMs = 250,
  } = {}) {
    this.#host = host;
    this.#port = port;
    this.#timeoutMs = timeoutMs;
    this.#connectRetries = connectRetries;
    this.#retryDelayMs = retryDelayMs;
  }

  async connect() {
    if (this.#socket && !this.#socket.destroyed) return;

    let lastError = null;
    for (let attempt = 0; attempt <= this.#connectRetries; attempt += 1) {
      try {
        await this.#connectOnce();
        return;
      } catch (error) {
        lastError = error;
        if (attempt < this.#connectRetries) await sleep(this.#retryDelayMs);
      }
    }

    throw new Error(
      `Night Circuit P3 connection failed: ${
        lastError instanceof Error ? lastError.message : "unknown error"
      }`,
      { cause: lastError },
    );
  }

  async #connectOnce() {
    const socket = net.createConnection({
      host: this.#host,
      port: this.#port,
    });

    await new Promise((resolve, reject) => {
      const cleanup = () => {
        socket.off("connect", onConnect);
        socket.off("error", onError);
      };
      const onConnect = () => {
        cleanup();
        resolve();
      };
      const onError = (error) => {
        cleanup();
        socket.destroy();
        reject(error);
      };
      socket.once("connect", onConnect);
      socket.once("error", onError);
    });

    this.#socket = socket;
    this.#buffer = "";

    socket.setNoDelay(true);
    socket.on("data", (chunk) => this.#onData(chunk));
    socket.on("error", (error) => this.#failPending(error));
    socket.on("close", () =>
      this.#failPending(new Error("Night Circuit P3 connection closed")),
    );
  }

  request(message) {
    this.#tail = this.#tail
      .catch(() => undefined)
      .then(() => this.#requestNow(message));
    return this.#tail;
  }

  async #requestNow(message) {
    await this.connect();
    if (!this.#socket || this.#socket.destroyed)
      throw new Error("Night Circuit P3 socket unavailable");

    const outbound = {
      ...clone(message),
      request_id:
        typeof message.request_id === "string" && message.request_id
          ? message.request_id
          : `pf-${Date.now()}-${Math.random().toString(16).slice(2, 10)}`,
    };

    return new Promise((resolve, reject) => {
      const timer = setTimeout(() => {
        if (this.#pending?.timer === timer) this.#pending = null;
        reject(new Error("Night Circuit P3 request timed out"));
      }, this.#timeoutMs);

      this.#pending = { resolve, reject, timer };

      this.#socket.write(`${JSON.stringify(outbound)}\n`, (error) => {
        if (!error) return;
        clearTimeout(timer);
        if (this.#pending?.timer === timer) this.#pending = null;
        reject(error);
      });
    });
  }

  #onData(chunk) {
    this.#buffer += chunk.toString("utf8");

    while (this.#buffer.includes("\n")) {
      const newline = this.#buffer.indexOf("\n");
      const line = this.#buffer.slice(0, newline).trim();
      this.#buffer = this.#buffer.slice(newline + 1);
      if (!line) continue;

      const pending = this.#pending;
      if (!pending) continue;

      this.#pending = null;
      clearTimeout(pending.timer);

      try {
        const response = JSON.parse(line);
        if (!response || typeof response !== "object" || Array.isArray(response))
          throw new TypeError("P3 response must be a JSON object");
        pending.resolve(response);
      } catch (error) {
        pending.reject(error);
      }
      break;
    }
  }

  #failPending(error) {
    if (!this.#pending) return;
    const pending = this.#pending;
    this.#pending = null;
    clearTimeout(pending.timer);
    pending.reject(error);
  }

  close() {
    if (this.#socket && !this.#socket.destroyed) this.#socket.destroy();
    this.#socket = null;
    this.#buffer = "";
  }
}

export function createNightCircuitP3BridgeV1({
  host = DEFAULT_HOST,
  port = DEFAULT_PORT,
  timeoutMs = 5_000,
  connectRetries = 0,
  retryDelayMs = 250,
  actionIntervalMs = DEFAULT_ACTION_INTERVAL_MS,
} = {}) {
  const client = new P3JsonlClient({
    host,
    port,
    timeoutMs,
    connectRetries,
    retryDelayMs,
  });

  let p3Description = null;
  let bridgeTick = 0;
  let sequence = 0;
  let lastActAt = 0;
  let lastObservation = null;
  const controllers = new Map();
  const pending = [];
  const ledger = [];
  const frames = [];

  async function remoteDescribe() {
    if (p3Description) return p3Description;

    const response = await client.request({ type: "describe" });
    if (response.ok !== true)
      throw new Error(
        `Night Circuit P3 describe failed: ${response.error ?? "unspecified"}`,
      );

    p3Description = clone(response.body ?? {});
    return p3Description;
  }

  function seatActions(description) {
    const seat = description?.seat ?? {};
    return Array.isArray(seat.action_surface)
      ? seat.action_surface.map((value) => String(value).toUpperCase())
      : [];
  }

  function actionsFromObservation(observation) {
    const capabilities = observation?.capabilities;
    if (!capabilities || typeof capabilities !== "object") return [];

    return Object.entries(capabilities)
      .filter(([, detail]) => detail?.available === true)
      .map(([action]) => action.toUpperCase());
  }

  function appendEvent(type, controllerId, payload) {
    sequence += 1;
    const event = {
      id: `p3e:${sequence}`,
      type,
      controllerId,
      bridgeTick,
      payload: clone(payload),
    };
    ledger.push(event);
    return event;
  }

  async function waitForActionSlot() {
    const elapsed = Date.now() - lastActAt;
    if (elapsed < actionIntervalMs)
      await sleep(actionIntervalMs - elapsed);
    lastActAt = Date.now();
  }

  const bridge = {
    async describe() {
      const description = await remoteDescribe();
      return {
        protocol: PROTOCOL,
        version: VERSION,
        gameId: "phi-night-circuit",
        runtimeVersion: `night-circuit/p3-tcp/${description.version ?? "0.3"}`,
        deterministic: false,
        clockMode: "engine",
        advanceSemantics: "flush-controller-batch",
        replayExact: false,
        transport: "tcp-jsonl",
        seatActor: "phi_bot",
      };
    },

    async registerController(descriptor) {
      if (!descriptor || typeof descriptor !== "object")
        return { ok: false, reason: "invalid_controller_descriptor" };

      const id = nonEmpty(descriptor.id, "controller.id");
      const actor = String(descriptor.actor ?? "phi_bot").toLowerCase();
      if (actor !== "phi_bot")
        return { ok: false, reason: "seat_actor_mismatch" };
      if (controllers.has(id))
        return { ok: false, reason: "controller_already_registered" };

      await remoteDescribe();
      controllers.set(id, {
        ...clone(descriptor),
        id,
        actor: "phi_bot",
      });
      return { ok: true };
    },

    async observe(controllerId, actorId) {
      if (!controllers.has(controllerId))
        throw new Error(`Controller not registered: ${controllerId}`);

      const actor = String(actorId ?? "phi_bot").toLowerCase();
      if (actor !== "phi_bot")
        throw new Error("Night Circuit P3 seat is locked to phi_bot");

      const response = await client.request({
        type: "observe",
        actor: "phi_bot",
      });
      if (response.ok !== true)
        throw new Error(
          `Night Circuit P3 observe failed: ${response.error ?? "unspecified"}`,
        );

      const observation = clone(response.body?.observation ?? {});
      observation.bridge = {
        protocol: PROTOCOL,
        version: VERSION,
        controllerId,
        bridgeTick,
        transport: "tcp-jsonl",
        allowed_actions: actionsFromObservation(observation),
      };

      lastObservation = clone(observation);
      return observation;
    },

    async submit(controllerId, intent, tick = bridgeTick) {
      pending.push({
        controllerId,
        tick,
        intent: clone(intent),
      });
      return { queued: true, tick };
    },

    async advance(roots = []) {
      const frameRoots = [...pending.splice(0), ...clone(roots)];
      const eventStart = ledger.length;

      for (const root of frameRoots) {
        const controllerId = String(
          root.controllerId ?? root.controller_id ?? "",
        );

        if (root.tick !== bridgeTick) {
          appendEvent("ACTION_REJECTED", controllerId, {
            reason: "wrong_tick",
            submittedTick: root.tick,
            bridgeTick,
          });
          continue;
        }

        if (!controllers.has(controllerId)) {
          appendEvent("ACTION_REJECTED", controllerId, {
            reason: "controller_not_registered",
          });
          continue;
        }

        const intent = root.intent ?? {};
        const actor = String(intent.actorId ?? intent.actor ?? "").toLowerCase();
        const action = String(intent.type ?? intent.action ?? "").toUpperCase();
        const payload = intent.params ?? intent.payload ?? {};

        if (actor !== "phi_bot") {
          appendEvent("ACTION_REJECTED", controllerId, {
            reason: "seat_actor_mismatch",
            actor,
            actionType: action,
          });
          continue;
        }

        await waitForActionSlot();

        const requestId =
          typeof intent.correlationId === "string" && intent.correlationId
            ? intent.correlationId
            : `pf-p3-${bridgeTick}-${sequence + 1}`;

        const response = await client.request({
          type: "act",
          actor: "phi_bot",
          action,
          payload,
          request_id: requestId,
        });

        const body = response.body ?? {};
        const decision = body.decision ?? {};
        const effect = body.effect ?? {};
        const accepted =
          response.ok === true && decision.accepted === true;

        appendEvent(
          accepted ? "ACTION_ACCEPTED" : "ACTION_REJECTED",
          controllerId,
          {
            actionType: action,
            requestId,
            reason:
              decision.reason ??
              response.error ??
              "unspecified",
            actionId: body.action_id ?? "",
            effectStatus: effect.status ?? "",
            effectReason: effect.reason ?? "",
            effect: effect.effect ?? {},
          },
        );
      }

      frames.push({
        tick: bridgeTick,
        roots: clone(frameRoots),
      });
      bridgeTick += 1;

      return clone(ledger.slice(eventStart));
    },

    async events(since = 0) {
      if (!Number.isSafeInteger(since) || since < 0)
        throw new TypeError("events(since) requires a non-negative integer");
      return clone(ledger.slice(since));
    },

    async snapshot() {
      const description = await remoteDescribe();
      return {
        schema: "night-circuit/p3-pixelforge-snapshot/0.1",
        restorable: false,
        bridgeTick,
        transport: {
          kind: "tcp-jsonl",
          host,
          port,
          seatActor: description.seat?.actor ?? "phi_bot",
        },
        controllers: Object.fromEntries(
          [...controllers.entries()].map(([id, value]) => [id, clone(value)]),
        ),
        authority: await bridge.authority(),
        eventCount: ledger.length,
        lastObservation: clone(lastObservation ?? {}),
      };
    },

    async recording() {
      return {
        schema: "night-circuit/p3-pixelforge-recording/0.1",
        exactReplay: false,
        clockMode: "engine",
        frames: clone(frames),
      };
    },

    async authority() {
      const description = await remoteDescribe();
      const actions = seatActions(description);
      return Object.fromEntries(
        [...controllers.keys()].map((id) => [
          id,
          { phi_bot: clone(actions) },
        ]),
      );
    },

    async hash() {
      const stable = {
        bridgeTick,
        controllers: [...controllers.keys()].sort(),
        events: ledger,
        lastObservation: lastObservation ?? {},
      };
      return createHash("sha256")
        .update(JSON.stringify(stable))
        .digest("hex");
    },

    close() {
      client.close();
    },
  };

  return bridge;
}
