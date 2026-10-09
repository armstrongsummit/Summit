-- Summit Farma B · carga directa y galería sin aprobación.
-- Ejecutar una vez en Supabase Dashboard > SQL Editor > New query.
-- Este script está diseñado para un proyecto nuevo del Summit.

insert into storage.buckets (id,name,public,file_size_limit,allowed_mime_types)
values ('summit-fotos','summit-fotos',false,3000000,array['image/jpeg'])
on conflict (id) do update set public=false,file_size_limit=3000000,allowed_mime_types=array['image/jpeg'];

create table if not exists public.photos (
 id uuid primary key default gen_random_uuid(),
 owner_id uuid not null references auth.users(id) on delete cascade,
 storage_path text not null unique,
 approved boolean not null default true,
 created_at timestamptz not null default now()
);
-- Compatibilidad con la versión anterior (si la tabla ya existe).
alter table public.photos alter column approved set default true;
create index if not exists photos_created_idx on public.photos (created_at desc);
create index if not exists photos_owner_idx on public.photos (owner_id);
alter table public.photos enable row level security;
revoke all on public.photos from anon;
grant select,insert on public.photos to authenticated;

drop policy if exists "photos_view_approved_or_own" on public.photos;
drop policy if exists "photos_insert_own" on public.photos;
drop policy if exists "photos_read_all" on public.photos;
drop policy if exists "photos_insert_public_own" on public.photos;
create policy "photos_read_all" on public.photos for select to authenticated
using (true);
create policy "photos_insert_public_own" on public.photos for insert to authenticated
with check (owner_id=(select auth.uid()) and approved=true
  and storage_path like ((select auth.uid())::text || '/%'));

-- Usuarios anónimos autenticados pueden subir JPG solo bajo su propio UID.
drop policy if exists "summit_upload_own" on storage.objects;
create policy "summit_upload_own" on storage.objects for insert to authenticated
with check (bucket_id='summit-fotos'
  and (storage.foldername(name))[1]=(select auth.uid())::text
  and lower(storage.extension(name))='jpg');

-- Fotos registradas se pueden leer por todos los participantes autenticados.
drop policy if exists "summit_read_approved_or_own" on storage.objects;
drop policy if exists "summit_read_all_photos" on storage.objects;
create policy "summit_read_all_photos" on storage.objects for select to authenticated
using (bucket_id='summit-fotos' and exists(
  select 1 from public.photos p where p.storage_path=name and p.approved=true
));

-- Sin políticas UPDATE/DELETE para los asistentes. El organizador podrá
-- gestionar imágenes en Supabase Dashboard. No agregar claves secretas a GitHub.
