"use server";

import { eq } from "drizzle-orm";
import { db } from "../db";
import { InsertExample, SelectExample } from "../schema/example-schema";
import { exampleTable } from "./../schema/example-schema";

export const createExample = async (data: InsertExample) => {
  try {
    const id = crypto.randomUUID();
    const now = new Date().toISOString();
    const exampleData = {
      ...data,
      id,
      createdAt: now,
      updatedAt: now
    };
    const result = db.insert(exampleTable).values(exampleData).run();
    return {
      ...exampleData,
      createdAt: now,
      updatedAt: now
    };
  } catch (error) {
    console.error("Error creating example:", error);
    throw new Error("Failed to create example");
  }
};

export const getExampleById = async (id: string) => {
  try {
    const example = db.query.exampleTable.findFirst({
      where: eq(exampleTable.id, id)
    });
    if (!example) {
      throw new Error("Example not found");
    }
    return example;
  } catch (error) {
    console.error("Error getting example by ID:", error);
    throw new Error("Failed to get example");
  }
};

export const getAllExamples = async (): Promise<SelectExample[]> => {
  return db.query.exampleTable.findMany();
};

export const updateExample = async (id: string, data: Partial<InsertExample>) => {
  try {
    const now = new Date().toISOString();
    const updateData = {
      ...data,
      updatedAt: now
    };
    db.update(exampleTable).set(updateData).where(eq(exampleTable.id, id)).run();
    // Get the updated record
    const updatedExample = db.query.exampleTable.findFirst({
      where: eq(exampleTable.id, id)
    });
    return updatedExample;
  } catch (error) {
    console.error("Error updating example:", error);
    throw new Error("Failed to update example");
  }
};

export const deleteExample = async (id: string) => {
  try {
    db.delete(exampleTable).where(eq(exampleTable.id, id)).run();
  } catch (error) {
    console.error("Error deleting example:", error);
    throw new Error("Failed to delete example");
  }
};