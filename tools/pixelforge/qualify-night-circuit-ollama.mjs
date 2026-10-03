import {
  AsyncRuntimeHostV1,
  createModelPolicyClientV1,
  createOllamaProviderV1,
} from "parallax-pixelforge/runtime";
import { createNightCircuitP3BridgeV1 } from "./p3-runtime-bridge.mjs";

function arg(name) {
  const prefix = `--${name}=`;
  const found = process.argv.slice(2).find((value) => value.startsWith(prefix));
  return found ? found.slice(prefix.length) : undefined;
}

const model =
  arg("model") ??
  process.env.OLLAMA_MODEL ??
  process.env.NIGHTCIRCUIT_OLLAMA_MODEL;
const baseUrl =
  arg("base-url") ??
  process.env.OLLAMA_BASE_URL ??
  "http://127.0.0.1:11434";

if (!model) {
  console.error(
    "Missing model. Set OLLAMA_MODEL/NIGHTCIRCUIT_OLLAMA_MODEL or pass --model=<installed-model>.",
  );
  process.exit(2);
}

const bridge = createNightCircuitP3BridgeV1({
  connectRetries: 20,
  retryDelayMs: 250,
});

try {
  const host = await AsyncRuntimeHostV1.connect(bridge);
  const provider = createOllamaProviderV1({
    model,
    baseUrl,
    options: { temperature: 0 },
  });

  const controllerId = "model:ollama-night-live";
  const client = createModelPolicyClientV1({
    id: controllerId,
    provider,
    actor: "phi_bot",
    profile: "actor_scoped",
    maxIntentsPerTurn: 1,
    instructions: [
      "You control only Φ-Bot in Night Circuit.",
      "Return exactly one HOLD intent and no other intents.",
      "Use actorId phi_bot and params {}.",
      "Do not control the Hunter.",
    ].join(" "),
  });

  await host.attachClient(client);
  const report = await host.turn(controllerId, "phi_bot");
  const after = await host.observe(controllerId, "phi_bot");

  const accepted = report.cycle.events.find(
    (event) =>
      event.type === "ACTION_ACCEPTED" &&
      event.controllerId === controllerId &&
      event.payload?.actionType === "HOLD" &&
      event.payload?.effectStatus === "applied",
  );

  if (!accepted || after.state?.mode !== "HOLD") {
    console.error("NIGHT CIRCUIT OLLAMA QUALIFICATION FAIL");
    console.error(
      JSON.stringify(
        {
          model,
          baseUrl,
          intents: report.intents,
          events: report.cycle.events,
          observation: after,
        },
        null,
        2,
      ),
    );
    process.exit(1);
  }

  console.log("NIGHT CIRCUIT OLLAMA QUALIFICATION PASS");
  console.log(
    JSON.stringify(
      {
        model,
        baseUrl,
        actor: after.actor,
        mode: after.state.mode,
        controlSource: after.state.control_source,
        action: accepted.payload.actionType,
        effect: accepted.payload.effectReason,
        runtimeHash: await host.hash(),
      },
      null,
      2,
    ),
  );
} catch (error) {
  console.error("NIGHT CIRCUIT OLLAMA QUALIFICATION FAIL");
  console.error(
    error instanceof Error ? error.stack ?? error.message : String(error),
  );
  process.exit(1);
} finally {
  bridge.close();
}
