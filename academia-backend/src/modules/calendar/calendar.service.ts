import { env } from '../../config/env.js';
import { AppError, ExternalServiceError } from '../../utils/errors.js';

/**
 * Module Google Calendar + Drive. Architecture préparée — à finaliser.
 */
export class CalendarService {
  protected requireGoogleConfig(): void {
    if (!env.GOOGLE_CLIENT_ID || !env.GOOGLE_CLIENT_SECRET || !env.GOOGLE_REFRESH_TOKEN) {
      throw new AppError(
        'Configuration Google incomplète (GOOGLE_CLIENT_ID / SECRET / REFRESH_TOKEN)',
        500,
        'GOOGLE_NOT_CONFIGURED',
      );
    }
  }

  /** Créer un événement (rendez-vous). */
  async createEvent(_input: {
    summary: string;
    start: string;
    end: string;
    attendees?: string[];
  }): Promise<unknown> {
    this.requireGoogleConfig();
    throw new ExternalServiceError('GoogleCalendar', 'createEvent() non encore implémenté');
  }

  /** Lister les événements à venir. */
  async listEvents(_timeMin?: string, _timeMax?: string): Promise<unknown> {
    throw new ExternalServiceError('GoogleCalendar', 'listEvents() non encore implémenté');
  }
}

export const calendarService = new CalendarService();
