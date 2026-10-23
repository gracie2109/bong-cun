// The salon works on Vietnam time whatever the device clock says. One definition of "today" for every screen.
const BUSINESS_TZ = "Asia/Ho_Chi_Minh";

const dateFormat = new Intl.DateTimeFormat("en-CA", { timeZone: BUSINESS_TZ });

/** yyyy-MM-dd of an instant on the salon's calendar. */
export const businessDateOf = (date: Date | string): string => dateFormat.format(new Date(date));

/** Today's date in Vietnam, whatever the device's time zone. */
export const todayInVietnam = (now = new Date()): string => businessDateOf(now);
