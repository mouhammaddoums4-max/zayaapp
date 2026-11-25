-- Relie les signaux serveur au distributeur FCM sans stocker le secret dans Git.
-- Les valeurs zaya_project_url et zaya_push_webhook_secret sont créées dans Vault
-- pour chaque environnement avant d'appliquer cette migration.

do $$
begin
  -- Absente de l'émulateur de test : l'extension n'est créée que si l'environnement la propose.
  if exists (select 1 from pg_available_extensions where name = 'pg_net') then
    create extension if not exists pg_net with schema extensions;
  end if;
end;
$$;

create or replace function public.dispatch_member_signal_webhook()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  project_url text;
  webhook_secret text;
begin
  select decrypted_secret into project_url
  from vault.decrypted_secrets
  where name = 'zaya_project_url';

  select decrypted_secret into webhook_secret
  from vault.decrypted_secrets
  where name = 'zaya_push_webhook_secret';

  -- Une panne de configuration des notifications ne doit pas bloquer les messages.
  if project_url is null or webhook_secret is null then
    return new;
  end if;

  perform net.http_post(
    url := project_url || '/functions/v1/push-dispatch',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-push-webhook-secret', webhook_secret
    ),
    body := jsonb_build_object(
      'type', tg_op,
      'table', tg_table_name,
      'schema', tg_table_schema,
      'record', to_jsonb(new),
      'old_record', null
    )
  );

  return new;
end;
$$;

revoke execute on function public.dispatch_member_signal_webhook() from public, anon, authenticated;

create trigger member_signals_push_webhook
  after insert on public.member_signals
  for each row execute function public.dispatch_member_signal_webhook();
