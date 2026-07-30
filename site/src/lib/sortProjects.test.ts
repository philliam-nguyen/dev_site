import { describe, expect, it } from 'vitest';
import { sortProjects } from './sortProjects';

const entry = (order: number, draft = false) => ({ data: { order, draft } });

describe('sortProjects', () => {
  it('sorts ascending by order', () => {
    const result = sortProjects([entry(30), entry(10), entry(20)]);
    expect(result.map(e => e.data.order)).toEqual([10, 20, 30]);
  });

  it('excludes drafts', () => {
    const result = sortProjects([entry(10), entry(20, true), entry(30)]);
    expect(result.map(e => e.data.order)).toEqual([10, 30]);
  });

  it('does not mutate the input array', () => {
    const input = [entry(30), entry(10)];
    sortProjects(input);
    expect(input.map(e => e.data.order)).toEqual([30, 10]);
  });

  it('returns an empty array when every entry is a draft', () => {
    expect(sortProjects([entry(10, true)])).toEqual([]);
  });
});
