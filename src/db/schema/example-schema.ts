import { integer, sqliteTable, text } from "drizzle-orm/sqlite-core";

export const exampleTable = sqliteTable("example", {
  id: text("id").primaryKey(),
  name: text("name").notNull(),
  age: integer("age").notNull(),
  email: text("email").notNull(),
  createdAt: text("created_at").notNull(),
  updatedAt: text("updated_at").notNull()
});

export type InsertExample = {
  name: string;
  age: number;
  email: string;
  id?: string;
  createdAt?: string;
  updatedAt?: string;
};
export type SelectExample = typeof exampleTable.$inferSelect;