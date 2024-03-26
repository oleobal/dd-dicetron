import "dotenv/config";
import express from "express";
import {
  InteractionType,
  InteractionResponseType,
  InteractionResponseFlags,
  MessageComponentTypes,
  ButtonStyleTypes,
} from "discord-interactions";
import { VerifyDiscordRequest, DiscordRequest } from "./utils.js";
import { getHelp, rollDice, UserInputError } from "./dice.js";

// Create an express app
const app = express();
// Get port, or default to 3000
const PORT = process.env.PORT || 3000;
// Parse request body and verifies incoming requests using discord-interactions package
if (process.env.DEV_MODE === "true") {
  app.use(express.json());
} else {
  app.use(
    express.json({ verify: VerifyDiscordRequest(process.env.PUBLIC_KEY) })
  );
}

/**
 * Interactions endpoint URL where Discord will send HTTP requests
 */
app.post("/interactions", async function (req, res) {
  // Interaction type and data
  const { type, id, data } = req.body;

  /**
   * Handle verification requests
   */
  if (type === InteractionType.PING) {
    return res.send({ type: InteractionResponseType.PONG });
  }

  /**
   * Handle slash command requests
   * See https://discord.com/developers/docs/interactions/application-commands#slash-commands
   */
  if (type === InteractionType.APPLICATION_COMMAND) {
    if (data.name === "help") {
      return res.send({
        type: InteractionResponseType.CHANNEL_MESSAGE_WITH_SOURCE,
        data: {
          content: getHelp(),
          flags: InteractionResponseFlags.EPHEMERAL,
        },
      });
    } else if (data.name === "roll") {
      let responseData;
      try {
        responseData = { content: rollDice(data.options[0].value) };
      } catch (e) {
        if (e instanceof UserInputError && e.message)
          responseData = {
            content: ":warning: " + e.message,
            flags: InteractionResponseFlags.EPHEMERAL,
          };
        else {
          console.log(e);
          responseData = {
            content: ":warning: Error",
            flags: InteractionResponseFlags.EPHEMERAL,
          };
        }
      }
      return res.send({
        type: InteractionResponseType.CHANNEL_MESSAGE_WITH_SOURCE,
        data: responseData,
      });
    } else {
      return res.send({ error: "unsupported interaction" });
    }
  }
});

app.listen(PORT, () => {
  console.log("Listening on port", PORT);
});
