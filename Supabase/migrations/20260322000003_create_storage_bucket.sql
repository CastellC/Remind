-- Evidence media storage bucket and policies
-- Path pattern: <user_id>/<entry_id>/<asset_id>.<ext>
-- First path segment must equal auth.uid()::text for all object operations.

-- ---------------------------------------------------------------------------
-- Private bucket
-- ---------------------------------------------------------------------------
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'evidence-media',
  'evidence-media',
  false,
  52428800, -- 50 MiB
  ARRAY[
    'image/jpeg',
    'image/png',
    'image/heic',
    'image/heif',
    'image/webp',
    'image/gif'
  ]
)
ON CONFLICT (id) DO UPDATE
SET
  public = EXCLUDED.public,
  file_size_limit = EXCLUDED.file_size_limit,
  allowed_mime_types = EXCLUDED.allowed_mime_types;

-- ---------------------------------------------------------------------------
-- Storage RLS policies for evidence-media
-- foldername(name)[1] is the first path segment (user id folder)
-- ---------------------------------------------------------------------------

-- SELECT (download / list)
CREATE POLICY evidence_media_select_own
  ON storage.objects FOR SELECT TO authenticated
  USING (
    bucket_id = 'evidence-media'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

-- INSERT (upload)
CREATE POLICY evidence_media_insert_own
  ON storage.objects FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'evidence-media'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

-- UPDATE (replace / metadata)
CREATE POLICY evidence_media_update_own
  ON storage.objects FOR UPDATE TO authenticated
  USING (
    bucket_id = 'evidence-media'
    AND (storage.foldername(name))[1] = auth.uid()::text
  )
  WITH CHECK (
    bucket_id = 'evidence-media'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

-- DELETE
CREATE POLICY evidence_media_delete_own
  ON storage.objects FOR DELETE TO authenticated
  USING (
    bucket_id = 'evidence-media'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

-- ---------------------------------------------------------------------------
-- Verification query examples
-- ---------------------------------------------------------------------------
-- -- Confirm bucket is private:
-- SELECT id, name, public, file_size_limit
-- FROM storage.buckets
-- WHERE id = 'evidence-media';
--
-- -- Confirm storage policies:
-- SELECT policyname, cmd, roles, qual, with_check
-- FROM pg_policies
-- WHERE schemaname = 'storage' AND tablename = 'objects'
--   AND policyname LIKE 'evidence_media_%';
--
-- -- Upload path must start with auth.uid():
-- -- <auth.uid()>/<entry_id>/<asset_id>.jpg  → allowed
-- -- <other-user-id>/<entry_id>/<asset_id>.jpg → denied by RLS
--
-- -- Example client path construction:
-- -- let path = "\(userId.uuidString.lowercased())/\(entryId.uuidString)/\(assetId.uuidString).jpg"
