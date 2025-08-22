export interface Task {
  id: string;
  title: string;
  description?: string;
}

export interface List {
  id: string;
  title: string;
  tasks: Task[];
}

export interface Project {
  id: string;
  title: string;
  lists: List[];
}
