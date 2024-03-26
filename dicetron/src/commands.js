import "dotenv/config";
import { InstallGlobalCommands } from "./utils.js";

const COMMANDS = [
  {
    name: "help",
    description: "Display help",
    type: 1,
  },
  {
    name: "roll",
    description: "Roll a set of dice",
    options: [
      {
        type: 3, // string
        name: "expr",
        description: "Dice expression",
        required: true,
      },
    ],
    type: 1,
  },
];

InstallGlobalCommands(process.env.APP_ID, COMMANDS);
