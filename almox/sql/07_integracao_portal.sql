-- Integração do Almoxarifado ao portal NEXUS (login único)
-- Todo login do portal ganha um cadastro em almox_usuarios (sem acesso a nenhuma unidade).
-- O acesso de fato é dado pelo gestor do Almoxarifado em Cadastros > Logins da unidade.

-- 1. Cadastro para os logins que já existem
insert into public.almox_usuarios (id, nome, email, papel, ativo, admin_sistema)
select u.id,
       coalesce(nullif(btrim(p.nome), ''), nullif(btrim(sp.nome), ''), split_part(u.email, '@', 1)),
       u.email, 'LEITURA', true, false
  from auth.users u
  left join public.perfis p on p.id = u.id
  left join seco.profiles sp on sp.id = u.id
on conflict (id) do nothing;

-- 2. Novos logins criados no portal entram automaticamente
create or replace function public.almox_fn_login_portal() returns trigger
language plpgsql security definer set search_path to 'public' as $$
begin
  begin
    insert into public.almox_usuarios (id, nome, email, papel, ativo, admin_sistema)
    values (new.id, coalesce(new.raw_user_meta_data->>'nome', new.raw_user_meta_data->>'name', split_part(new.email, '@', 1)),
            new.email, 'LEITURA', true, false)
    on conflict (id) do nothing;
  exception when others then null; -- nunca impede a criação do login no portal
  end;
  return new;
end $$;
drop trigger if exists almox_trg_login_portal on auth.users;
create trigger almox_trg_login_portal after insert on auth.users
  for each row execute function public.almox_fn_login_portal();

-- 3. Módulo aparece no portal para quem tem acesso a alguma unidade
create or replace function nexus.meus_modulos() returns jsonb
language sql stable security definer set search_path to '' as $$
  select jsonb_build_object(
    'seco', (select jsonb_build_object('role',role,'setor',setor,'nome',nome) from seco.profiles where id=auth.uid() and ativo),
    'cmv',  (select jsonb_build_object('papel',papel,'nome',nome) from public.perfis where id=auth.uid() and ativo),
    'almox', (select jsonb_build_object('nome', u.nome, 'unidades', count(*))
                from public.almox_usuarios u join public.almox_acessos a on a.usuario_id = u.id and a.ativo
                join public.almox_unidades un on un.id = a.unidade_id and un.ativo
               where u.id = auth.uid() and u.ativo group by u.nome),
    'gestor', nexus.is_gestor()
  )
$$;
