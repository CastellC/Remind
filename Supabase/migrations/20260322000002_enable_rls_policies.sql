-- Evidence app Row Level Security
-- Every user-owned table: SELECT/INSERT/UPDATE/DELETE only when user_id = auth.uid().
-- Join tables also carry user_id; ownership is enforced both by RLS and by schema triggers.

-- ---------------------------------------------------------------------------
-- Enable RLS on all user-owned tables
-- ---------------------------------------------------------------------------
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.evidence_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.evidence_tags ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.evidence_entry_tags ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.evidence_entry_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.check_ins ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.recommendation_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.recommendation_session_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.recommendation_feedback ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reminder_preferences ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.meaningful_date_reminders ENABLE ROW LEVEL SECURITY;

-- Force RLS for table owners as well (defense in depth for non-superuser roles).
ALTER TABLE public.profiles FORCE ROW LEVEL SECURITY;
ALTER TABLE public.evidence_entries FORCE ROW LEVEL SECURITY;
ALTER TABLE public.evidence_tags FORCE ROW LEVEL SECURITY;
ALTER TABLE public.evidence_entry_tags FORCE ROW LEVEL SECURITY;
ALTER TABLE public.categories FORCE ROW LEVEL SECURITY;
ALTER TABLE public.evidence_entry_categories FORCE ROW LEVEL SECURITY;
ALTER TABLE public.check_ins FORCE ROW LEVEL SECURITY;
ALTER TABLE public.recommendation_sessions FORCE ROW LEVEL SECURITY;
ALTER TABLE public.recommendation_session_items FORCE ROW LEVEL SECURITY;
ALTER TABLE public.recommendation_feedback FORCE ROW LEVEL SECURITY;
ALTER TABLE public.reminder_preferences FORCE ROW LEVEL SECURITY;
ALTER TABLE public.meaningful_date_reminders FORCE ROW LEVEL SECURITY;

-- ---------------------------------------------------------------------------
-- Helper: standard owner policies per table
-- ---------------------------------------------------------------------------

-- profiles
CREATE POLICY profiles_select_own
  ON public.profiles FOR SELECT TO authenticated
  USING (user_id = auth.uid());

CREATE POLICY profiles_insert_own
  ON public.profiles FOR INSERT TO authenticated
  WITH CHECK (user_id = auth.uid());

CREATE POLICY profiles_update_own
  ON public.profiles FOR UPDATE TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

CREATE POLICY profiles_delete_own
  ON public.profiles FOR DELETE TO authenticated
  USING (user_id = auth.uid());

-- evidence_entries
CREATE POLICY evidence_entries_select_own
  ON public.evidence_entries FOR SELECT TO authenticated
  USING (user_id = auth.uid());

CREATE POLICY evidence_entries_insert_own
  ON public.evidence_entries FOR INSERT TO authenticated
  WITH CHECK (user_id = auth.uid());

CREATE POLICY evidence_entries_update_own
  ON public.evidence_entries FOR UPDATE TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

CREATE POLICY evidence_entries_delete_own
  ON public.evidence_entries FOR DELETE TO authenticated
  USING (user_id = auth.uid());

-- evidence_tags
CREATE POLICY evidence_tags_select_own
  ON public.evidence_tags FOR SELECT TO authenticated
  USING (user_id = auth.uid());

CREATE POLICY evidence_tags_insert_own
  ON public.evidence_tags FOR INSERT TO authenticated
  WITH CHECK (user_id = auth.uid());

CREATE POLICY evidence_tags_update_own
  ON public.evidence_tags FOR UPDATE TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

CREATE POLICY evidence_tags_delete_own
  ON public.evidence_tags FOR DELETE TO authenticated
  USING (user_id = auth.uid());

-- evidence_entry_tags
-- Direct user_id ownership plus parent ownership via EXISTS.
CREATE POLICY evidence_entry_tags_select_own
  ON public.evidence_entry_tags FOR SELECT TO authenticated
  USING (
    user_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM public.evidence_entries e
      WHERE e.id = evidence_entry_id AND e.user_id = auth.uid()
    )
  );

CREATE POLICY evidence_entry_tags_insert_own
  ON public.evidence_entry_tags FOR INSERT TO authenticated
  WITH CHECK (
    user_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM public.evidence_entries e
      WHERE e.id = evidence_entry_id AND e.user_id = auth.uid()
    )
    AND EXISTS (
      SELECT 1 FROM public.evidence_tags t
      WHERE t.id = evidence_tag_id AND t.user_id = auth.uid()
    )
  );

CREATE POLICY evidence_entry_tags_update_own
  ON public.evidence_entry_tags FOR UPDATE TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (
    user_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM public.evidence_entries e
      WHERE e.id = evidence_entry_id AND e.user_id = auth.uid()
    )
    AND EXISTS (
      SELECT 1 FROM public.evidence_tags t
      WHERE t.id = evidence_tag_id AND t.user_id = auth.uid()
    )
  );

CREATE POLICY evidence_entry_tags_delete_own
  ON public.evidence_entry_tags FOR DELETE TO authenticated
  USING (user_id = auth.uid());

-- categories
CREATE POLICY categories_select_own
  ON public.categories FOR SELECT TO authenticated
  USING (user_id = auth.uid());

CREATE POLICY categories_insert_own
  ON public.categories FOR INSERT TO authenticated
  WITH CHECK (user_id = auth.uid());

CREATE POLICY categories_update_own
  ON public.categories FOR UPDATE TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

CREATE POLICY categories_delete_own
  ON public.categories FOR DELETE TO authenticated
  USING (user_id = auth.uid());

-- evidence_entry_categories
CREATE POLICY evidence_entry_categories_select_own
  ON public.evidence_entry_categories FOR SELECT TO authenticated
  USING (
    user_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM public.evidence_entries e
      WHERE e.id = evidence_entry_id AND e.user_id = auth.uid()
    )
  );

CREATE POLICY evidence_entry_categories_insert_own
  ON public.evidence_entry_categories FOR INSERT TO authenticated
  WITH CHECK (
    user_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM public.evidence_entries e
      WHERE e.id = evidence_entry_id AND e.user_id = auth.uid()
    )
    AND EXISTS (
      SELECT 1 FROM public.categories c
      WHERE c.id = category_id AND c.user_id = auth.uid()
    )
  );

CREATE POLICY evidence_entry_categories_update_own
  ON public.evidence_entry_categories FOR UPDATE TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (
    user_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM public.evidence_entries e
      WHERE e.id = evidence_entry_id AND e.user_id = auth.uid()
    )
    AND EXISTS (
      SELECT 1 FROM public.categories c
      WHERE c.id = category_id AND c.user_id = auth.uid()
    )
  );

CREATE POLICY evidence_entry_categories_delete_own
  ON public.evidence_entry_categories FOR DELETE TO authenticated
  USING (user_id = auth.uid());

-- check_ins
CREATE POLICY check_ins_select_own
  ON public.check_ins FOR SELECT TO authenticated
  USING (user_id = auth.uid());

CREATE POLICY check_ins_insert_own
  ON public.check_ins FOR INSERT TO authenticated
  WITH CHECK (user_id = auth.uid());

CREATE POLICY check_ins_update_own
  ON public.check_ins FOR UPDATE TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

CREATE POLICY check_ins_delete_own
  ON public.check_ins FOR DELETE TO authenticated
  USING (user_id = auth.uid());

-- recommendation_sessions
CREATE POLICY recommendation_sessions_select_own
  ON public.recommendation_sessions FOR SELECT TO authenticated
  USING (user_id = auth.uid());

CREATE POLICY recommendation_sessions_insert_own
  ON public.recommendation_sessions FOR INSERT TO authenticated
  WITH CHECK (
    user_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM public.check_ins c
      WHERE c.id = check_in_id AND c.user_id = auth.uid()
    )
  );

CREATE POLICY recommendation_sessions_update_own
  ON public.recommendation_sessions FOR UPDATE TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (
    user_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM public.check_ins c
      WHERE c.id = check_in_id AND c.user_id = auth.uid()
    )
  );

CREATE POLICY recommendation_sessions_delete_own
  ON public.recommendation_sessions FOR DELETE TO authenticated
  USING (user_id = auth.uid());

-- recommendation_session_items
CREATE POLICY recommendation_session_items_select_own
  ON public.recommendation_session_items FOR SELECT TO authenticated
  USING (
    user_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM public.recommendation_sessions s
      WHERE s.id = session_id AND s.user_id = auth.uid()
    )
  );

CREATE POLICY recommendation_session_items_insert_own
  ON public.recommendation_session_items FOR INSERT TO authenticated
  WITH CHECK (
    user_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM public.recommendation_sessions s
      WHERE s.id = session_id AND s.user_id = auth.uid()
    )
    AND (
      evidence_entry_id IS NULL
      OR EXISTS (
        SELECT 1 FROM public.evidence_entries e
        WHERE e.id = evidence_entry_id AND e.user_id = auth.uid()
      )
    )
  );

CREATE POLICY recommendation_session_items_update_own
  ON public.recommendation_session_items FOR UPDATE TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (
    user_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM public.recommendation_sessions s
      WHERE s.id = session_id AND s.user_id = auth.uid()
    )
    AND (
      evidence_entry_id IS NULL
      OR EXISTS (
        SELECT 1 FROM public.evidence_entries e
        WHERE e.id = evidence_entry_id AND e.user_id = auth.uid()
      )
    )
  );

CREATE POLICY recommendation_session_items_delete_own
  ON public.recommendation_session_items FOR DELETE TO authenticated
  USING (user_id = auth.uid());

-- recommendation_feedback
CREATE POLICY recommendation_feedback_select_own
  ON public.recommendation_feedback FOR SELECT TO authenticated
  USING (user_id = auth.uid());

CREATE POLICY recommendation_feedback_insert_own
  ON public.recommendation_feedback FOR INSERT TO authenticated
  WITH CHECK (user_id = auth.uid());

CREATE POLICY recommendation_feedback_update_own
  ON public.recommendation_feedback FOR UPDATE TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

CREATE POLICY recommendation_feedback_delete_own
  ON public.recommendation_feedback FOR DELETE TO authenticated
  USING (user_id = auth.uid());

-- reminder_preferences
CREATE POLICY reminder_preferences_select_own
  ON public.reminder_preferences FOR SELECT TO authenticated
  USING (user_id = auth.uid());

CREATE POLICY reminder_preferences_insert_own
  ON public.reminder_preferences FOR INSERT TO authenticated
  WITH CHECK (user_id = auth.uid());

CREATE POLICY reminder_preferences_update_own
  ON public.reminder_preferences FOR UPDATE TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

CREATE POLICY reminder_preferences_delete_own
  ON public.reminder_preferences FOR DELETE TO authenticated
  USING (user_id = auth.uid());

-- meaningful_date_reminders
CREATE POLICY meaningful_date_reminders_select_own
  ON public.meaningful_date_reminders FOR SELECT TO authenticated
  USING (user_id = auth.uid());

CREATE POLICY meaningful_date_reminders_insert_own
  ON public.meaningful_date_reminders FOR INSERT TO authenticated
  WITH CHECK (
    user_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM public.evidence_entries e
      WHERE e.id = evidence_entry_id AND e.user_id = auth.uid()
    )
  );

CREATE POLICY meaningful_date_reminders_update_own
  ON public.meaningful_date_reminders FOR UPDATE TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (
    user_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM public.evidence_entries e
      WHERE e.id = evidence_entry_id AND e.user_id = auth.uid()
    )
  );

CREATE POLICY meaningful_date_reminders_delete_own
  ON public.meaningful_date_reminders FOR DELETE TO authenticated
  USING (user_id = auth.uid());

-- ---------------------------------------------------------------------------
-- Verification query examples (run manually as an authenticated user JWT)
-- ---------------------------------------------------------------------------
-- -- Expect only the current user's rows:
-- SELECT id, user_id FROM public.evidence_entries;
-- SELECT id, user_id FROM public.check_ins;
-- SELECT id, user_id FROM public.profiles;
--
-- -- Expect INSERT to succeed when user_id = auth.uid():
-- INSERT INTO public.profiles (user_id, display_name)
-- VALUES (auth.uid(), 'Test');
--
-- -- Expect INSERT to fail when user_id ≠ auth.uid() (RLS WITH CHECK):
-- INSERT INTO public.profiles (user_id, display_name)
-- VALUES ('00000000-0000-0000-0000-000000000000', 'Other');
--
-- -- Expect UPDATE of another user's row to affect 0 rows:
-- UPDATE public.evidence_entries
-- SET title = 'hijack'
-- WHERE user_id <> auth.uid();
--
-- -- Expect DELETE of another user's row to affect 0 rows:
-- DELETE FROM public.evidence_tags WHERE user_id <> auth.uid();
--
-- -- Join table: INSERT must reference own entry + own tag:
-- INSERT INTO public.evidence_entry_tags (user_id, evidence_entry_id, evidence_tag_id)
-- VALUES (auth.uid(), '<own-entry-uuid>', '<own-tag-uuid>');
--
-- -- Confirm RLS is enabled:
-- SELECT schemaname, tablename, rowsecurity
-- FROM pg_tables
-- WHERE schemaname = 'public'
--   AND tablename IN (
--     'profiles', 'evidence_entries', 'evidence_tags', 'evidence_entry_tags',
--     'categories', 'evidence_entry_categories', 'check_ins',
--     'recommendation_sessions', 'recommendation_session_items',
--     'recommendation_feedback', 'reminder_preferences', 'meaningful_date_reminders'
--   );
--
-- -- Confirm policies exist:
-- SELECT schemaname, tablename, policyname, cmd, roles
-- FROM pg_policies
-- WHERE schemaname = 'public'
-- ORDER BY tablename, policyname;
--
-- -- Local-only check-in note constraint (should fail):
-- INSERT INTO public.check_ins (
--   user_id, emotion, support_need, note_is_local_only, optional_note
-- ) VALUES (
--   auth.uid(), 'anxious', 'reassurance', true, 'should not sync'
-- );
