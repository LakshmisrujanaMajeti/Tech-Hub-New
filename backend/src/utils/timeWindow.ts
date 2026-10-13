/**
 * Utilities for enforcing the daily attendance operating window:
 * 09:00 AM to 04:00 PM (IST / Asia/Kolkata).
 */

export interface AttendanceWindowInfo {
  isOpen: boolean;
  status: 'OPEN' | 'TIMED_OUT' | 'NOT_OPEN_YET';
  message: string;
  windowStart: string;
  windowEnd: string;
  currentIstTime: string;
  minutesRemaining?: number;
}

export function getISTDateComponents(date: Date = new Date()): {
  year: number;
  month: number;
  day: number;
  hour: number;
  minute: number;
  second: number;
  dateStr: string;
  timeStr: string;
} {
  const parts = new Intl.DateTimeFormat('en-US', {
    timeZone: 'Asia/Kolkata',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
    hour12: false,
  }).formatToParts(date);

  const getPart = (type: string) => {
    const p = parts.find((pt) => pt.type === type);
    return p ? parseInt(p.value, 10) : 0;
  };

  const year = getPart('year');
  const month = getPart('month');
  const day = getPart('day');
  const hour = getPart('hour');
  const minute = getPart('minute');
  const second = getPart('second');

  const pad = (n: number) => n.toString().padStart(2, '0');
  const dateStr = `${year}-${pad(month)}-${pad(day)}`;
  const timeStr = `${pad(hour)}:${pad(minute)}:${pad(second)}`;

  return { year, month, day, hour, minute, second, dateStr, timeStr };
}

export function isWithinAttendanceWindow(date: Date = new Date()): boolean {
  const { hour } = getISTDateComponents(date);
  // Attendance working hours: 09:00 AM to 04:00 PM (16:00)
  return hour >= 9 && hour < 16;
}

export function getAttendanceWindowInfo(date: Date = new Date()): AttendanceWindowInfo {
  const { hour, minute, timeStr } = getISTDateComponents(date);
  const isOpen = hour >= 9 && hour < 16;

  if (hour < 9) {
    return {
      isOpen: false,
      status: 'NOT_OPEN_YET',
      message: 'Daily attendance window opens at 09:00 AM. Operating hours are 09:00 AM to 04:00 PM.',
      windowStart: '09:00 AM',
      windowEnd: '04:00 PM',
      currentIstTime: timeStr,
    };
  }

  if (hour >= 16) {
    return {
      isOpen: false,
      status: 'TIMED_OUT',
      message: "Daily attendance window timed out for today at 04:00 PM. Reopens tomorrow morning at 09:00 AM.",
      windowStart: '09:00 AM',
      windowEnd: '04:00 PM',
      currentIstTime: timeStr,
    };
  }

  const minutesRemaining = (15 - hour) * 60 + (60 - minute);
  return {
    isOpen: true,
    status: 'OPEN',
    message: `Attendance window active. Closes at 04:00 PM (${minutesRemaining} mins remaining).`,
    windowStart: '09:00 AM',
    windowEnd: '04:00 PM',
    currentIstTime: timeStr,
    minutesRemaining,
  };
}

/**
 * Clamp validity timestamp so it does not exceed 04:00 PM IST today.
 */
export function clampSlotExpiryTo4PM(validUntil: Date): Date {
  const { year, month, day } = getISTDateComponents(new Date());
  // Construct 16:00:00 IST date
  const pad = (n: number) => n.toString().padStart(2, '0');
  const today4PmIst = new Date(`${year}-${pad(month)}-${pad(day)}T16:00:00+05:30`);

  if (validUntil.getTime() > today4PmIst.getTime()) {
    return today4PmIst;
  }
  return validUntil;
}
