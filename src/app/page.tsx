"use client";

import { useState, useEffect } from "react";
import { createExampleAction, getAllExamplesAction, deleteExampleAction } from "@/actions/example-actions";
import { InsertExample } from "@/db/schema/example-schema";
import { ActionState } from "@/types";

export default function Home() {
  const [examples, setExamples] = useState<any[]>([]);
  const [loading, setLoading] = useState(false);
  const [message, setMessage] = useState("");

  const loadExamples = async () => {
    setLoading(true);
    const result: ActionState = await getAllExamplesAction();
    if (result.status === "success") {
      setExamples(result.data || []);
    } else {
      setMessage(result.message);
    }
    setLoading(false);
  };

  const createExample = async () => {
    setLoading(true);
    const exampleData: InsertExample = {
      name: "Test User",
      age: 25,
      email: "test@example.com"
    };
    const result: ActionState = await createExampleAction(exampleData);
    setMessage(result.message);
    if (result.status === "success") {
      await loadExamples();
    }
    setLoading(false);
  };

  const deleteExample = async (id: string) => {
    setLoading(true);
    const result: ActionState = await deleteExampleAction(id);
    setMessage(result.message);
    if (result.status === "success") {
      await loadExamples();
    }
    setLoading(false);
  };

  useEffect(() => {
    loadExamples();
  }, []);

  return (
    <div className="container mx-auto p-4">
      <h1 className="text-2xl font-bold mb-4">Backend Setup Test</h1>

      {message && (
        <div className={`mb-4 p-2 rounded ${message.includes("success") ? "bg-green-100 text-green-800" : "bg-red-100 text-red-800"}`}>
          {message}
        </div>
      )}

      <div className="mb-4">
        <button
          onClick={createExample}
          disabled={loading}
          className="bg-blue-500 text-white px-4 py-2 rounded disabled:opacity-50"
        >
          {loading ? "Loading..." : "Create Test Example"}
        </button>
        <button
          onClick={loadExamples}
          disabled={loading}
          className="bg-gray-500 text-white px-4 py-2 rounded ml-2 disabled:opacity-50"
        >
          {loading ? "Loading..." : "Refresh Examples"}
        </button>
      </div>

      <div className="border rounded p-4">
        <h2 className="text-lg font-semibold mb-2">Examples ({examples.length})</h2>
        {examples.length === 0 ? (
          <p className="text-gray-500">No examples found. Click "Create Test Example" to add one.</p>
        ) : (
          <div className="space-y-2">
            {examples.map((example) => (
              <div key={example.id} className="border rounded p-2 flex justify-between items-center">
                <div>
                  <strong>{example.name}</strong> - {example.email} - Age: {example.age}
                  <br />
                  <small className="text-gray-500">Created: {new Date(example.createdAt).toLocaleString()}</small>
                </div>
                <button
                  onClick={() => deleteExample(example.id)}
                  disabled={loading}
                  className="bg-red-500 text-white px-3 py-1 rounded text-sm disabled:opacity-50"
                >
                  Delete
                </button>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}