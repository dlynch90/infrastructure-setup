import { config } from "dotenv";
import { drizzle } from "drizzle-orm/better-sqlite3";
import Database from "better-sqlite3";
import { exampleTable } from "./schema";

config({ path: ".env.local" });

// Use SQLite for local development
const sqlite = new Database("dev.db");

const schema = {
  exampleTable
};

export const db = drizzle(sqlite, { schema });