import assert from "node:assert/strict";

import {
  AsyncRuntimeHostV1,
  createModelPolicyClientV1,
  createOllamaProviderV1,
} from "parallax-pixelforge/runtime";
import { createNightCircuitP3BridgeV1 } from "./p3-runtime-bridge.mjs";

function jsonResponse(payload, { ok = true, status = 200 } = {}) {
  return {
    ok,
    status,
    async json() {
      return structuredClone(payload);
    },
  };
}

const bridge = createNightCircuitP3BridgeV1({
  connectRetries: 60,
  retryDelayMs: 250,
  timeoutMs: 5_000,
});

try {
  const host = await AsyncRuntimeHostV1.connect(bridge);

  assert.equal(host.descriptor.gameId, "phi-night-circuit");
  assert.equal(host.semantics.deterministic, false);
  assert.equal(host.semantics.clockMode, "engine");
  assert.equal(host.semantics.advanceSemantics, "flush-controller-batch");

  const provider = createOllamaProviderV1({
    model: "night-circuit-fixture-model",
    fetchImpl: async (_url, init) => {
      const body = JSON.parse(init.body);
      const request = JSON.parse(body.messages[1].content);
      const observation = request.observation;

      assert.equal(observation.actor, "phi_bot");
      assert.equal(observation.capabilities.HOLD.available, true);
      assert.ok(observation.bridge.allowed_actions.includes("HOLD"));
      assert.equal(observation.metadata.scope, "phi_bot");

      return jsonResponse({
        model: "night-circuit-fixture-model",
        done: true,
        done_reason: "stop",
        message: {
          role: "assistant",
          content: JSON.stringify({
            schema: "pixelforge/model-policy-response/1",
            intents: [
              {
                actorId: "phi_bot",
                type: "HOLD",
                params: {},
                correlationId: "nc019-model-hold",
              },
            ],
          }),
        },
      });
    },
  });

  const model = createModelPolicyClientV1({
    id: "model:ollama-night",
    provider,
    actor: "phi_bot",
    profile: "actor_scoped",
    maxIntentsPerTurn: 1,
    instructions: [
      "Control only Φ-Bot from the bounded observation.",
      "Return exactly one HOLD intent.",
      "Do not control the Hunter or invent actions.",
    ].join(" "),
  });

  await host.attachClient(model);

  const authority = await host.authority();
  assert.ok(authority["model:ollama-night"].phi_bot.includes("HOLD"));
  assert.equal(authority["model:ollama-night"].hunter, undefined);

  const before = await host.observe("model:ollama-night", "phi_bot");
  assert.equal(before.capabilities.HOLD.available, true);

  const turn = await host.turn("model:ollama-night", "phi_bot");

  assert.equal(turn.intents.length, 1);
  assert.equal(turn.intents[0].type, "HOLD");

  const accepted = turn.cycle.events.find(
    (event) =>
      event.type === "ACTION_ACCEPTED" &&
      event.controllerId === "model:ollama-night" &&
      event.payload?.actionType === "HOLD",
  );
  assert.ok(accepted);
  assert.equal(accepted.payload.requestId, "nc019-model-hold");
  assert.equal(accepted.payload.effectStatus, "applied");
  assert.equal(accepted.payload.effectReason, "hold_enabled");

  const after = await host.observe("model:ollama-night", "phi_bot");
  assert.equal(after.state.mode, "HOLD");
  assert.equal(after.state.control_source, "agent");

  const modelReceipts = model.modelReceipts();
  assert.ok(modelReceipts.some((receipt) => receipt.type === "MODEL_REQUEST_BUILT"));
  assert.ok(modelReceipts.some((receipt) => receipt.type === "MODEL_PROVIDER_COMPLETED"));
  assert.ok(modelReceipts.some((receipt) => receipt.type === "MODEL_INTENTS_PARSED"));

  const hostReceipts = host.receipts();
  assert.ok(hostReceipts.some((receipt) => receipt.type === "CLIENT_ATTACHED"));
  assert.ok(hostReceipts.some((receipt) => receipt.type === "INTENT_QUEUED"));
  assert.ok(hostReceipts.some((receipt) => receipt.type === "CLIENT_TURN_COMPLETED"));

  const recording = await host.recording();
  const roots = recording.frames.flatMap((frame) => frame.roots);
  assert.ok(
    roots.some(
      (root) =>
        root.controllerId === "model:ollama-night" &&
        root.intent?.correlationId === "nc019-model-hold",
    ),
  );

  const malformedProvider = createOllamaProviderV1({
    model: "night-circuit-bad-model",
    fetchImpl: async () =>
      jsonResponse({
        model: "night-circuit-bad-model",
        done: true,
        message: {
          role: "assistant",
          content: "HOLD PLEASE",
        },
      }),
  });

  const badModel = createModelPolicyClientV1({
    id: "model:ollama-night-bad",
    provider: malformedProvider,
    actor: "phi_bot",
    profile: "actor_scoped",
  });
  await host.attachClient(badModel);

  await assert.rejects(
    () => host.turn("model:ollama-night-bad", "phi_bot"),
    /valid JSON|JSON object/i,
  );

  assert.equal((await host.pollEvents()).length, 0);
  const stillHeld = await host.observe("model:ollama-night-bad", "phi_bot");
  assert.equal(stillHeld.state.mode, "HOLD");
  assert.ok(
    badModel
      .modelReceipts()
      .some((receipt) => receipt.type === "MODEL_TURN_FAILED"),
  );

  console.log("NC-019 PixelForge async model seat: PASS");
  console.log(
    JSON.stringify(
      {
        gameId: host.descriptor.gameId,
        transport: host.descriptor.transport,
        actor: after.actor,
        action: accepted.payload.actionType,
        effect: accepted.payload.effectReason,
        mode: after.state.mode,
        controlSource: after.state.control_source,
        runtimeHash: await host.hash(),
      },
      null,
      2,
    ),
  );
} finally {
  bridge.close();
}
