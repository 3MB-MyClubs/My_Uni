-- Media Delivery v2: align the existing chat picker/player/uploader contract.
-- The private bucket and its participant-based SELECT policies are unchanged.
-- Originals are uploaded as selected; this does not add video transcoding.
update storage.buckets
set
  file_size_limit = 10485760,
  allowed_mime_types = array[
    'image/jpeg',
    'image/png',
    'image/webp',
    'image/gif',
    'image/heic',
    'image/heif',
    'video/mp4',
    'video/quicktime',
    'video/x-m4v',
    'video/x-msvideo',
    'video/webm',
    'video/x-matroska',
    'video/3gpp'
  ]
where id = 'chat-attachments';
