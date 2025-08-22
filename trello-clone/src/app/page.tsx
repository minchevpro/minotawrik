"use client";

import React, { useState } from 'react';
import Link from 'next/link';
import { Project } from '@/types';

export default function Home() {
  const [projects, setProjects] = useState<Project[]>([
    {
      id: '1',
      title: 'Project Alpha',
      lists: [],
    },
    {
      id: '2',
      title: 'Project Beta',
      lists: [],
    },
  ]);

  const [newProjectName, setNewProjectName] = useState('');
  const [isModalOpen, setIsModalOpen] = useState(false);

  const handleCreateProject = () => {
    if (newProjectName.trim()) {
      const newProject: Project = {
        id: (projects.length + 1).toString(),
        title: newProjectName,
        lists: [
          { id: '1', title: 'To Do', tasks: [] },
          { id: '2', title: 'In Progress', tasks: [] },
          { id: '3', title: 'Done', tasks: [] },
        ],
      };
      setProjects([...projects, newProject]);
      setNewProjectName('');
      setIsModalOpen(false);
    }
  };

  return (
    <div className="container mx-auto p-4">
      <header className="flex justify-between items-center mb-6">
        <h1 className="text-2xl font-bold">My Projects</h1>
        <button
          onClick={() => setIsModalOpen(true)}
          className="bg-blue-500 hover:bg-blue-700 text-white font-bold py-2 px-4 rounded"
        >
          Create New Project
        </button>
      </header>
      <main>
        <div className="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-4">
          {projects.map((project) => (
            <Link key={project.id} href={`/projects/${project.id}`}>
              <div className="p-4 border rounded-lg shadow hover:bg-gray-50 cursor-pointer">
                <h2 className="font-bold text-lg mb-2">{project.title}</h2>
              </div>
            </Link>
          ))}
        </div>
      </main>

      {isModalOpen && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center">
          <div className="bg-white p-6 rounded-lg shadow-xl">
            <h2 className="text-xl font-bold mb-4">Create New Project</h2>
            <input
              type="text"
              value={newProjectName}
              onChange={(e) => setNewProjectName(e.target.value)}
              className="border p-2 rounded w-full mb-4"
              placeholder="Project Name"
            />
            <div className="flex justify-end space-x-2">
              <button
                onClick={() => setIsModalOpen(false)}
                className="bg-gray-300 hover:bg-gray-400 text-black font-bold py-2 px-4 rounded"
              >
                Cancel
              </button>
              <button
                onClick={handleCreateProject}
                className="bg-blue-500 hover:bg-blue-700 text-white font-bold py-2 px-4 rounded"
              >
                Create
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
