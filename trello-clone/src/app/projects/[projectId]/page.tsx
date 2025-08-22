"use client";

import React, { useState } from 'react';
import { List, Task } from '@/types';

type PageProps = {
  params: {
    projectId: string;
  };
};

// Mock data for initial lists and tasks.
// In a real application, this would be fetched from a database.
const initialLists: List[] = [
  {
    id: '1',
    title: 'To Do',
    tasks: [
      { id: '1-1', title: 'Task 1' },
      { id: '1-2', title: 'Task 2' },
    ],
  },
  {
    id: '2',
    title: 'In Progress',
    tasks: [{ id: '2-1', title: 'Task 3' }],
  },
];

export default function ProjectPage({ params }: PageProps) {
  // State for the lists on the board
  const [lists, setLists] = useState<List[]>(initialLists);

  // State for adding a new list
  const [newListName, setNewListName] = useState('');
  const [addingList, setAddingList] = useState(false);

  // State for adding a new task
  const [addingTaskInList, setAddingTaskInList] = useState<string | null>(null);
  const [newTaskTitle, setNewTaskTitle] = useState('');

  // State for the currently selected task (for viewing/editing details)
  const [selectedTask, setSelectedTask] = useState<Task | null>(null);

  /**
   * Handles the creation of a new list.
   */
  const handleAddList = () => {
    if (newListName.trim()) {
      const newList: List = {
        id: Date.now().toString(),
        title: newListName,
        tasks: [],
      };
      setLists([...lists, newList]);
      setNewListName('');
      setAddingList(false);
    }
  };

  /**
   * Handles the creation of a new task in a specific list.
   * @param listId The ID of the list to add the task to.
   */
  const handleAddTask = (listId: string) => {
    if (newTaskTitle.trim()) {
      const newTask: Task = {
        id: Date.now().toString(),
        title: newTaskTitle,
      };
      const newLists = lists.map((list) => {
        if (list.id === listId) {
          return { ...list, tasks: [...list.tasks, newTask] };
        }
        return list;
      });
      setLists(newLists);
      setNewTaskTitle('');
      setAddingTaskInList(null);
    }
  };

  /**
   * Handles updating the description of a task.
   * @param description The new description for the task.
   */
  const handleUpdateTaskDescription = (description: string) => {
    if (selectedTask) {
      const newLists = lists.map(list => ({
        ...list,
        tasks: list.tasks.map(task =>
          task.id === selectedTask.id ? { ...task, description } : task
        )
      }));
      setLists(newLists);
      setSelectedTask(prev => prev ? { ...prev, description } : null);
    }
  };

  return (
    <div className="container mx-auto p-4">
      <header className="mb-6">
        <h1 className="text-2xl font-bold">Project {params.projectId}</h1>
      </header>
      <main className="flex space-x-4 overflow-x-auto pb-4">
        {lists.map((list) => (
          <div key={list.id} className="bg-gray-100 rounded-lg p-3 w-72 flex-shrink-0">
            <h2 className="font-bold mb-3">{list.title}</h2>
            <div className="space-y-3">
              {list.tasks.map((task) => (
                <div
                  key={task.id}
                  onClick={() => setSelectedTask(task)}
                  className="bg-white p-3 rounded-md shadow cursor-pointer"
                >
                  <p>{task.title}</p>
                </div>
              ))}
            </div>
            {/* Form for adding a new task */}
            {addingTaskInList === list.id ? (
              <div className="mt-3">
                <input
                  type="text"
                  value={newTaskTitle}
                  onChange={(e) => setNewTaskTitle(e.target.value)}
                  className="border p-2 rounded w-full mb-2"
                  placeholder="Task Title"
                  autoFocus
                />
                <div className="flex justify-end space-x-2">
                  <button onClick={() => setAddingTaskInList(null)} className="text-sm">Cancel</button>
                  <button onClick={() => handleAddTask(list.id)} className="bg-blue-500 text-white text-sm py-1 px-2 rounded">Add</button>
                </div>
              </div>
            ) : (
              <button
                onClick={() => setAddingTaskInList(list.id)}
                className="mt-3 text-sm text-gray-600 hover:text-gray-800 w-full text-left"
              >
                + Add a card
              </button>
            )}
          </div>
        ))}
        <div className="w-72 flex-shrink-0">
          {/* Form for adding a new list */}
          {addingList ? (
            <div>
              <input
                type="text"
                value={newListName}
                onChange={(e) => setNewListName(e.target.value)}
                className="border p-2 rounded w-full mb-2"
                placeholder="List Name"
                autoFocus
              />
              <div className="flex justify-end space-x-2">
                <button onClick={() => setAddingList(false)} className="text-sm">Cancel</button>
                <button onClick={handleAddList} className="bg-blue-500 text-white text-sm py-1 px-2 rounded">Add</button>
              </div>
            </div>
          ) : (
            <button
              onClick={() => setAddingList(true)}
              className="bg-gray-200 hover:bg-gray-300 text-gray-800 font-bold py-2 px-4 rounded w-full"
            >
              + Add another list
            </button>
          )}
        </div>
      </main>

      {/* Modal for viewing/editing a task */}
      {selectedTask && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center" onClick={() => setSelectedTask(null)}>
          <div className="bg-white p-6 rounded-lg shadow-xl w-1/3" onClick={(e) => e.stopPropagation()}>
            <h2 className="text-xl font-bold mb-4">{selectedTask.title}</h2>
            <p className="text-gray-600 mb-2">in list <strong>{lists.find(l => l.tasks.some(t => t.id === selectedTask.id))?.title}</strong></p>
            <h3 className="font-bold mt-4 mb-2">Description</h3>
            <textarea
              className="border p-2 rounded w-full"
              placeholder="Add a more detailed description..."
              defaultValue={selectedTask.description}
              onBlur={(e) => handleUpdateTaskDescription(e.target.value)}
            />
            <div className="flex justify-end mt-4">
              <button onClick={() => setSelectedTask(null)} className="bg-gray-300 hover:bg-gray-400 text-black font-bold py-2 px-4 rounded">
                Close
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
