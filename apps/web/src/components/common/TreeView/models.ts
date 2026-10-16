export type TreeViewSelectionMode = "independent" | "leaf";

export interface TreeViewNodeItem {
  id: number;
  name: string;
  icon?:string;
  children?: TreeViewNodeItem[];
  showBox?:boolean
}