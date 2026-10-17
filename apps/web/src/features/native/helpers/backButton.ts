export type BackAction = "back" | "exit";

/** Android Back: step back through the app's own history, leave the app only from the first screen. */
export const decideBackAction = (historyPosition: number | undefined, path: string): BackAction =>
  path === "/" || !historyPosition || historyPosition <= 0 ? "exit" : "back";
