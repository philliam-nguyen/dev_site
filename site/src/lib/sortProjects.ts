export type SortableProject = {
  data: { order: number; draft: boolean };
};

export function sortProjects<T extends SortableProject>(entries: T[]): T[] {
  return entries
    .filter(entry => !entry.data.draft)
    .sort((a, b) => a.data.order - b.data.order);
}
