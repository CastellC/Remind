-- Evidence app schema
-- Tables mirror local SwiftData models for cloud sync (guided content stays local-only for MVP).

-- ---------------------------------------------------------------------------
-- Extensions
-- ---------------------------------------------------------------------------
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ---------------------------------------------------------------------------
-- updated_at trigger helper
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = timezone('utc', now());
  RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.set_updated_at() IS
  'Sets NEW.updated_at to UTC now() on row UPDATE.';

-- ---------------------------------------------------------------------------
-- profiles
-- ---------------------------------------------------------------------------
CREATE TABLE public.profiles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL UNIQUE REFERENCES auth.users (id) ON DELETE CASCADE,
  display_name text,
  onboarding_completed_at timestamptz,
  selected_use_cases text[] NOT NULL DEFAULT '{}',
  app_lock_enabled boolean NOT NULL DEFAULT false,
  notification_preview_mode text NOT NULL DEFAULT 'generic'
    CHECK (notification_preview_mode IN ('generic', 'titleOnly', 'fullContent')),
  has_seen_safety_information boolean NOT NULL DEFAULT false,
  cloud_sync_enabled boolean NOT NULL DEFAULT false,
  last_successful_sync_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  updated_at timestamptz NOT NULL DEFAULT timezone('utc', now())
);

CREATE INDEX profiles_user_id_idx ON public.profiles (user_id);
CREATE INDEX profiles_updated_at_idx ON public.profiles (updated_at);

CREATE TRIGGER profiles_set_updated_at
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW
  EXECUTE PROCEDURE public.set_updated_at();

COMMENT ON TABLE public.profiles IS
  'Per-user app profile and preference flags synced from the iOS client.';

-- ---------------------------------------------------------------------------
-- evidence_entries
-- ---------------------------------------------------------------------------
CREATE TABLE public.evidence_entries (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
  title text NOT NULL,
  body_text text,
  entry_type text NOT NULL
    CHECK (entry_type IN (
      'text',
      'image',
      'guidedReminder',
      'groundingTechnique',
      'accomplishment',
      'meaningfulMemory'
    )),
  source_type text NOT NULL
    CHECK (source_type IN (
      'self',
      'friend',
      'family',
      'partner',
      'coworker',
      'manager',
      'teacherOrMentor',
      'professional',
      'bookOrArticle',
      'socialMedia',
      'unknown',
      'other'
    )),
  source_name text,
  source_context text,
  original_url_string text,
  occurred_at timestamptz,
  meaningful_date timestamptz,
  is_favorite boolean NOT NULL DEFAULT false,
  is_archived boolean NOT NULL DEFAULT false,
  is_sensitive boolean NOT NULL DEFAULT false,
  exclude_from_check_ins boolean NOT NULL DEFAULT false,
  exclude_from_notifications boolean NOT NULL DEFAULT false,
  user_authored boolean NOT NULL DEFAULT true,
  import_method text
    CHECK (
      import_method IS NULL
      OR import_method IN (
        'manual',
        'photosPicker',
        'shareImport',
        'paste',
        'fileImport',
        'unknown'
      )
    ),
  meaning_prompt_answer text NOT NULL,
  remote_media_path text,
  accessibility_description text,
  deleted_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  updated_at timestamptz NOT NULL DEFAULT timezone('utc', now())
);

CREATE INDEX evidence_entries_user_id_idx
  ON public.evidence_entries (user_id);
CREATE INDEX evidence_entries_updated_at_idx
  ON public.evidence_entries (updated_at);
CREATE INDEX evidence_entries_deleted_at_idx
  ON public.evidence_entries (deleted_at);
CREATE INDEX evidence_entries_user_active_idx
  ON public.evidence_entries (user_id, updated_at DESC)
  WHERE deleted_at IS NULL;
CREATE INDEX evidence_entries_user_favorite_idx
  ON public.evidence_entries (user_id)
  WHERE is_favorite = true AND deleted_at IS NULL;
CREATE INDEX evidence_entries_meaningful_date_idx
  ON public.evidence_entries (user_id, meaningful_date)
  WHERE meaningful_date IS NOT NULL AND deleted_at IS NULL;

CREATE TRIGGER evidence_entries_set_updated_at
  BEFORE UPDATE ON public.evidence_entries
  FOR EACH ROW
  EXECUTE PROCEDURE public.set_updated_at();

COMMENT ON TABLE public.evidence_entries IS
  'Personal evidence items. Soft-deleted via deleted_at for sync-safe removal.';
COMMENT ON COLUMN public.evidence_entries.meaning_prompt_answer IS
  'Required answer to “Why might future you need this?”';
COMMENT ON COLUMN public.evidence_entries.remote_media_path IS
  'Storage object path: <user_id>/<entry_id>/<asset_id>.<ext>';

-- ---------------------------------------------------------------------------
-- evidence_tags
-- ---------------------------------------------------------------------------
CREATE TABLE public.evidence_tags (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
  name text NOT NULL,
  tag_type text NOT NULL
    CHECK (tag_type IN (
      'emotion',
      'supportNeed',
      'strength',
      'lifeArea',
      'theme',
      'person',
      'occasion'
    )),
  origin text NOT NULL DEFAULT 'user'
    CHECK (origin IN ('user', 'system', 'futureModelSuggested', 'futureModelConfirmed')),
  is_system_tag boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  updated_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  CONSTRAINT evidence_tags_user_name_type_unique UNIQUE (user_id, name, tag_type)
);

CREATE INDEX evidence_tags_user_id_idx ON public.evidence_tags (user_id);
CREATE INDEX evidence_tags_updated_at_idx ON public.evidence_tags (updated_at);
CREATE INDEX evidence_tags_tag_type_idx ON public.evidence_tags (user_id, tag_type);

CREATE TRIGGER evidence_tags_set_updated_at
  BEFORE UPDATE ON public.evidence_tags
  FOR EACH ROW
  EXECUTE PROCEDURE public.set_updated_at();

COMMENT ON TABLE public.evidence_tags IS
  'User and system tags attached to evidence entries.';

-- ---------------------------------------------------------------------------
-- evidence_entry_tags (join)
-- ---------------------------------------------------------------------------
CREATE TABLE public.evidence_entry_tags (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
  evidence_entry_id uuid NOT NULL REFERENCES public.evidence_entries (id) ON DELETE CASCADE,
  evidence_tag_id uuid NOT NULL REFERENCES public.evidence_tags (id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  updated_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  CONSTRAINT evidence_entry_tags_pair_unique UNIQUE (evidence_entry_id, evidence_tag_id)
);

CREATE INDEX evidence_entry_tags_user_id_idx
  ON public.evidence_entry_tags (user_id);
CREATE INDEX evidence_entry_tags_entry_id_idx
  ON public.evidence_entry_tags (evidence_entry_id);
CREATE INDEX evidence_entry_tags_tag_id_idx
  ON public.evidence_entry_tags (evidence_tag_id);

CREATE TRIGGER evidence_entry_tags_set_updated_at
  BEFORE UPDATE ON public.evidence_entry_tags
  FOR EACH ROW
  EXECUTE PROCEDURE public.set_updated_at();

COMMENT ON TABLE public.evidence_entry_tags IS
  'Many-to-many link between evidence_entries and evidence_tags.';

-- ---------------------------------------------------------------------------
-- categories
-- ---------------------------------------------------------------------------
CREATE TABLE public.categories (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
  name text NOT NULL,
  icon_name text,
  sort_order integer NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  updated_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  CONSTRAINT categories_user_name_unique UNIQUE (user_id, name)
);

CREATE INDEX categories_user_id_idx ON public.categories (user_id);
CREATE INDEX categories_updated_at_idx ON public.categories (updated_at);
CREATE INDEX categories_sort_order_idx ON public.categories (user_id, sort_order);

CREATE TRIGGER categories_set_updated_at
  BEFORE UPDATE ON public.categories
  FOR EACH ROW
  EXECUTE PROCEDURE public.set_updated_at();

COMMENT ON TABLE public.categories IS
  'User-defined collection categories.';

-- ---------------------------------------------------------------------------
-- evidence_entry_categories (join)
-- ---------------------------------------------------------------------------
CREATE TABLE public.evidence_entry_categories (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
  evidence_entry_id uuid NOT NULL REFERENCES public.evidence_entries (id) ON DELETE CASCADE,
  category_id uuid NOT NULL REFERENCES public.categories (id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  updated_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  CONSTRAINT evidence_entry_categories_pair_unique UNIQUE (evidence_entry_id, category_id)
);

CREATE INDEX evidence_entry_categories_user_id_idx
  ON public.evidence_entry_categories (user_id);
CREATE INDEX evidence_entry_categories_entry_id_idx
  ON public.evidence_entry_categories (evidence_entry_id);
CREATE INDEX evidence_entry_categories_category_id_idx
  ON public.evidence_entry_categories (category_id);

CREATE TRIGGER evidence_entry_categories_set_updated_at
  BEFORE UPDATE ON public.evidence_entry_categories
  FOR EACH ROW
  EXECUTE PROCEDURE public.set_updated_at();

COMMENT ON TABLE public.evidence_entry_categories IS
  'Many-to-many link between evidence_entries and categories.';

-- ---------------------------------------------------------------------------
-- check_ins (recommendation_session_id FK added after sessions table)
-- ---------------------------------------------------------------------------
CREATE TABLE public.check_ins (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
  completed_at timestamptz,
  emotion text NOT NULL
    CHECK (emotion IN (
      'anxious',
      'down',
      'selfCritical',
      'lonely',
      'overwhelmed',
      'angry',
      'ashamed',
      'uncertain',
      'numb',
      'notSure'
    )),
  intensity integer
    CHECK (intensity IS NULL OR (intensity >= 1 AND intensity <= 10)),
  support_need text NOT NULL
    CHECK (support_need IN (
      'reassurance',
      'perspective',
      'grounding',
      'evidenceOfCapability',
      'evidenceOfConnection',
      'evidenceOfGrowth',
      'oneSmallStep',
      'quietReflection'
    )),
  optional_note text,
  safety_state text NOT NULL DEFAULT 'standard'
    CHECK (safety_state IN ('standard', 'elevatedConcern', 'immediateConcern')),
  recommendation_session_id uuid,
  note_is_local_only boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  updated_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  CONSTRAINT check_ins_local_note_null_chk
    CHECK (NOT note_is_local_only OR optional_note IS NULL)
);

CREATE INDEX check_ins_user_id_idx ON public.check_ins (user_id);
CREATE INDEX check_ins_updated_at_idx ON public.check_ins (updated_at);
CREATE INDEX check_ins_created_at_idx ON public.check_ins (user_id, created_at DESC);
CREATE INDEX check_ins_recommendation_session_id_idx
  ON public.check_ins (recommendation_session_id);

CREATE TRIGGER check_ins_set_updated_at
  BEFORE UPDATE ON public.check_ins
  FOR EACH ROW
  EXECUTE PROCEDURE public.set_updated_at();

COMMENT ON TABLE public.check_ins IS
  'Emotional check-ins that drive recommendation sessions.';
COMMENT ON COLUMN public.check_ins.note_is_local_only IS
  'When true, optional_note must be null on the server (note stays on device).';
COMMENT ON CONSTRAINT check_ins_local_note_null_chk ON public.check_ins IS
  'Enforces: note_is_local_only = true ⇒ optional_note IS NULL.';

-- ---------------------------------------------------------------------------
-- recommendation_sessions
-- ---------------------------------------------------------------------------
CREATE TABLE public.recommendation_sessions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
  check_in_id uuid NOT NULL REFERENCES public.check_ins (id) ON DELETE CASCADE,
  completed_at timestamptz,
  current_index integer NOT NULL DEFAULT 0 CHECK (current_index >= 0),
  created_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  updated_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  CONSTRAINT recommendation_sessions_check_in_unique UNIQUE (check_in_id)
);

CREATE INDEX recommendation_sessions_user_id_idx
  ON public.recommendation_sessions (user_id);
CREATE INDEX recommendation_sessions_updated_at_idx
  ON public.recommendation_sessions (updated_at);
CREATE INDEX recommendation_sessions_check_in_id_idx
  ON public.recommendation_sessions (check_in_id);

CREATE TRIGGER recommendation_sessions_set_updated_at
  BEFORE UPDATE ON public.recommendation_sessions
  FOR EACH ROW
  EXECUTE PROCEDURE public.set_updated_at();

COMMENT ON TABLE public.recommendation_sessions IS
  'One recommendation browse session per check-in.';

-- Resolve circular reference: check_ins → recommendation_sessions
ALTER TABLE public.check_ins
  ADD CONSTRAINT check_ins_recommendation_session_id_fkey
  FOREIGN KEY (recommendation_session_id)
  REFERENCES public.recommendation_sessions (id)
  ON DELETE SET NULL;

-- ---------------------------------------------------------------------------
-- recommendation_session_items
-- ---------------------------------------------------------------------------
CREATE TABLE public.recommendation_session_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
  session_id uuid NOT NULL REFERENCES public.recommendation_sessions (id) ON DELETE CASCADE,
  evidence_entry_id uuid REFERENCES public.evidence_entries (id) ON DELETE SET NULL,
  guided_content_id uuid,
  sequence_position integer NOT NULL CHECK (sequence_position >= 0),
  score double precision NOT NULL DEFAULT 0,
  selection_reason text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  updated_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  CONSTRAINT recommendation_session_items_session_position_unique
    UNIQUE (session_id, sequence_position),
  CONSTRAINT recommendation_session_items_content_present_chk
    CHECK (evidence_entry_id IS NOT NULL OR guided_content_id IS NOT NULL)
);

CREATE INDEX recommendation_session_items_user_id_idx
  ON public.recommendation_session_items (user_id);
CREATE INDEX recommendation_session_items_session_id_idx
  ON public.recommendation_session_items (session_id);
CREATE INDEX recommendation_session_items_evidence_entry_id_idx
  ON public.recommendation_session_items (evidence_entry_id);

CREATE TRIGGER recommendation_session_items_set_updated_at
  BEFORE UPDATE ON public.recommendation_session_items
  FOR EACH ROW
  EXECUTE PROCEDURE public.set_updated_at();

COMMENT ON TABLE public.recommendation_session_items IS
  'Ordered recommendation candidates for a session. guided_content_id is a local UUID reference (guided content is not stored remotely for MVP).';

-- ---------------------------------------------------------------------------
-- recommendation_feedback
-- ---------------------------------------------------------------------------
CREATE TABLE public.recommendation_feedback (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
  recommendation_session_id uuid REFERENCES public.recommendation_sessions (id) ON DELETE SET NULL,
  check_in_id uuid REFERENCES public.check_ins (id) ON DELETE SET NULL,
  evidence_entry_id uuid REFERENCES public.evidence_entries (id) ON DELETE SET NULL,
  guided_content_id uuid,
  response text NOT NULL
    CHECK (response IN (
      'helped',
      'noChange',
      'madeThingsHarder',
      'notRelevant',
      'notNow',
      'showLessOften',
      'doNotUseForThisFeeling'
    )),
  emotion_at_time text
    CHECK (
      emotion_at_time IS NULL
      OR emotion_at_time IN (
        'anxious',
        'down',
        'selfCritical',
        'lonely',
        'overwhelmed',
        'angry',
        'ashamed',
        'uncertain',
        'numb',
        'notSure'
      )
    ),
  support_need_at_time text
    CHECK (
      support_need_at_time IS NULL
      OR support_need_at_time IN (
        'reassurance',
        'perspective',
        'grounding',
        'evidenceOfCapability',
        'evidenceOfConnection',
        'evidenceOfGrowth',
        'oneSmallStep',
        'quietReflection'
      )
    ),
  created_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  updated_at timestamptz NOT NULL DEFAULT timezone('utc', now())
);

CREATE INDEX recommendation_feedback_user_id_idx
  ON public.recommendation_feedback (user_id);
CREATE INDEX recommendation_feedback_updated_at_idx
  ON public.recommendation_feedback (updated_at);
CREATE INDEX recommendation_feedback_session_id_idx
  ON public.recommendation_feedback (recommendation_session_id);
CREATE INDEX recommendation_feedback_check_in_id_idx
  ON public.recommendation_feedback (check_in_id);
CREATE INDEX recommendation_feedback_evidence_entry_id_idx
  ON public.recommendation_feedback (evidence_entry_id);

CREATE TRIGGER recommendation_feedback_set_updated_at
  BEFORE UPDATE ON public.recommendation_feedback
  FOR EACH ROW
  EXECUTE PROCEDURE public.set_updated_at();

COMMENT ON TABLE public.recommendation_feedback IS
  'User feedback on recommended evidence or guided content.';

-- ---------------------------------------------------------------------------
-- reminder_preferences (one row per user)
-- ---------------------------------------------------------------------------
CREATE TABLE public.reminder_preferences (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL UNIQUE REFERENCES auth.users (id) ON DELETE CASCADE,
  is_enabled boolean NOT NULL DEFAULT false,
  selected_weekdays smallint[] NOT NULL DEFAULT '{}',
  delivery_hour integer NOT NULL DEFAULT 9
    CHECK (delivery_hour >= 0 AND delivery_hour <= 23),
  delivery_minute integer NOT NULL DEFAULT 0
    CHECK (delivery_minute >= 0 AND delivery_minute <= 59),
  frequency text NOT NULL DEFAULT 'weekly'
    CHECK (frequency IN ('daily', 'weekly', 'custom')),
  allowed_category_ids uuid[] NOT NULL DEFAULT '{}',
  generic_preview_only boolean NOT NULL DEFAULT true,
  last_scheduled_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  updated_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  CONSTRAINT reminder_preferences_weekdays_valid_chk
    CHECK (
      selected_weekdays <@ ARRAY[0, 1, 2, 3, 4, 5, 6]::smallint[]
    )
);

CREATE INDEX reminder_preferences_user_id_idx
  ON public.reminder_preferences (user_id);
CREATE INDEX reminder_preferences_updated_at_idx
  ON public.reminder_preferences (updated_at);

CREATE TRIGGER reminder_preferences_set_updated_at
  BEFORE UPDATE ON public.reminder_preferences
  FOR EACH ROW
  EXECUTE PROCEDURE public.set_updated_at();

COMMENT ON TABLE public.reminder_preferences IS
  'General reminder schedule preferences. At most one row per user (UNIQUE user_id).';
COMMENT ON COLUMN public.reminder_preferences.selected_weekdays IS
  'Weekdays as smallint 0=Sunday … 6=Saturday (Calendar weekday convention).';

-- ---------------------------------------------------------------------------
-- meaningful_date_reminders
-- ---------------------------------------------------------------------------
CREATE TABLE public.meaningful_date_reminders (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
  evidence_entry_id uuid NOT NULL REFERENCES public.evidence_entries (id) ON DELETE CASCADE,
  reminder_date date NOT NULL,
  recurrence text NOT NULL DEFAULT 'yearly'
    CHECK (recurrence IN ('none', 'yearly', 'monthly')),
  enabled boolean NOT NULL DEFAULT true,
  label text,
  reminder_hour integer NOT NULL DEFAULT 9
    CHECK (reminder_hour >= 0 AND reminder_hour <= 23),
  reminder_minute integer NOT NULL DEFAULT 0
    CHECK (reminder_minute >= 0 AND reminder_minute <= 59),
  created_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  updated_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  CONSTRAINT meaningful_date_reminders_entry_unique UNIQUE (evidence_entry_id)
);

CREATE INDEX meaningful_date_reminders_user_id_idx
  ON public.meaningful_date_reminders (user_id);
CREATE INDEX meaningful_date_reminders_updated_at_idx
  ON public.meaningful_date_reminders (updated_at);
CREATE INDEX meaningful_date_reminders_entry_id_idx
  ON public.meaningful_date_reminders (evidence_entry_id);
CREATE INDEX meaningful_date_reminders_date_idx
  ON public.meaningful_date_reminders (user_id, reminder_date)
  WHERE enabled = true;

CREATE TRIGGER meaningful_date_reminders_set_updated_at
  BEFORE UPDATE ON public.meaningful_date_reminders
  FOR EACH ROW
  EXECUTE PROCEDURE public.set_updated_at();

COMMENT ON TABLE public.meaningful_date_reminders IS
  'Optional anniversary-style reminders tied to an evidence entry.';

-- ---------------------------------------------------------------------------
-- Ownership helpers for join-table integrity (entry/tag/category same user)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.enforce_entry_tag_same_user()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  entry_user uuid;
  tag_user uuid;
BEGIN
  SELECT user_id INTO entry_user FROM public.evidence_entries WHERE id = NEW.evidence_entry_id;
  SELECT user_id INTO tag_user FROM public.evidence_tags WHERE id = NEW.evidence_tag_id;

  IF entry_user IS NULL OR tag_user IS NULL THEN
    RAISE EXCEPTION 'evidence_entry_tags references missing entry or tag';
  END IF;

  IF NEW.user_id IS DISTINCT FROM entry_user OR NEW.user_id IS DISTINCT FROM tag_user THEN
    RAISE EXCEPTION 'evidence_entry_tags.user_id must match both entry and tag owners';
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER evidence_entry_tags_same_user
  BEFORE INSERT OR UPDATE ON public.evidence_entry_tags
  FOR EACH ROW
  EXECUTE PROCEDURE public.enforce_entry_tag_same_user();

CREATE OR REPLACE FUNCTION public.enforce_entry_category_same_user()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  entry_user uuid;
  category_user uuid;
BEGIN
  SELECT user_id INTO entry_user FROM public.evidence_entries WHERE id = NEW.evidence_entry_id;
  SELECT user_id INTO category_user FROM public.categories WHERE id = NEW.category_id;

  IF entry_user IS NULL OR category_user IS NULL THEN
    RAISE EXCEPTION 'evidence_entry_categories references missing entry or category';
  END IF;

  IF NEW.user_id IS DISTINCT FROM entry_user OR NEW.user_id IS DISTINCT FROM category_user THEN
    RAISE EXCEPTION 'evidence_entry_categories.user_id must match both entry and category owners';
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER evidence_entry_categories_same_user
  BEFORE INSERT OR UPDATE ON public.evidence_entry_categories
  FOR EACH ROW
  EXECUTE PROCEDURE public.enforce_entry_category_same_user();

CREATE OR REPLACE FUNCTION public.enforce_session_item_same_user()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  session_user uuid;
  entry_user uuid;
BEGIN
  SELECT user_id INTO session_user FROM public.recommendation_sessions WHERE id = NEW.session_id;

  IF session_user IS NULL THEN
    RAISE EXCEPTION 'recommendation_session_items references missing session';
  END IF;

  IF NEW.user_id IS DISTINCT FROM session_user THEN
    RAISE EXCEPTION 'recommendation_session_items.user_id must match session owner';
  END IF;

  IF NEW.evidence_entry_id IS NOT NULL THEN
    SELECT user_id INTO entry_user FROM public.evidence_entries WHERE id = NEW.evidence_entry_id;
    IF entry_user IS NULL OR entry_user IS DISTINCT FROM NEW.user_id THEN
      RAISE EXCEPTION 'recommendation_session_items evidence_entry_id must belong to the same user';
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER recommendation_session_items_same_user
  BEFORE INSERT OR UPDATE ON public.recommendation_session_items
  FOR EACH ROW
  EXECUTE PROCEDURE public.enforce_session_item_same_user();
