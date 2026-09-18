-- =====================================================================
-- Progresso das alunas na apostila do DIA 2
-- Projeto: Cadastro de Creators (mfrmnquvwwuxraqgemyh)
--
-- 100% ADITIVO: cria 1 tabela nova e 2 funções novas, do mesmo jeito
-- que o dia 1. Não altera nada da imersao_progresso, então o
-- acompanhamento do dia 1 continua funcionando durante a aula.
-- =====================================================================

create table if not exists public.imersao_progresso_d2 (
  id        bigserial primary key,
  arroba    text not null unique,
  nome      text,
  email     text,
  whatsapp  text,
  etapa     text,
  feitos    jsonb not null default '[]'::jsonb,
  marcados  int  not null default 0,
  total     int  not null default 0,
  criado_em timestamptz not null default now(),
  visto_em  timestamptz not null default now()
);

alter table public.imersao_progresso_d2 enable row level security;

drop policy if exists imersao_progresso_d2_admin on public.imersao_progresso_d2;
create policy imersao_progresso_d2_admin on public.imersao_progresso_d2
  for all to authenticated using (is_admin()) with check (is_admin());

-- A porta de entrada da aluna: só essa função escreve, e só a linha dela.
create or replace function public.imersao_salvar_progresso_d2(
  p_arroba text, p_nome text, p_email text, p_whatsapp text,
  p_etapa text, p_feitos jsonb, p_marcados int, p_total int
) returns void language plpgsql security definer set search_path = public as $fn$
declare a text; n text; e text; w text;
begin
  a := lower(regexp_replace(coalesce(p_arroba,''), '[^a-zA-Z0-9._]', '', 'g'));
  if a = '' or length(a) > 40 then return; end if;
  n := nullif(trim(coalesce(p_nome,'')),'');
  e := lower(nullif(trim(coalesce(p_email,'')),''));
  w := nullif(regexp_replace(coalesce(p_whatsapp,''), '[^0-9]', '', 'g'),'');
  insert into imersao_progresso_d2 (arroba, nome, email, whatsapp, etapa, feitos, marcados, total)
  values (a, left(n,80), left(e,120), left(w,20), left(coalesce(p_etapa,''),8),
          coalesce(p_feitos,'[]'::jsonb), coalesce(p_marcados,0), coalesce(p_total,0))
  on conflict (arroba) do update set
    nome     = coalesce(excluded.nome,     imersao_progresso_d2.nome),
    email    = coalesce(excluded.email,    imersao_progresso_d2.email),
    whatsapp = coalesce(excluded.whatsapp, imersao_progresso_d2.whatsapp),
    etapa    = excluded.etapa,
    feitos   = excluded.feitos,
    marcados = excluded.marcados,
    total    = excluded.total,
    visto_em = now();
end $fn$;

revoke all on function public.imersao_salvar_progresso_d2(text,text,text,text,text,jsonb,int,int) from public;
grant execute on function public.imersao_salvar_progresso_d2(text,text,text,text,text,jsonb,int,int) to anon, authenticated;

-- A leitura da Lara, igual à do dia 1.
create or replace function public.admin_imersao_progresso_d2()
returns setof imersao_progresso_d2 language sql security definer set search_path = public as $fn$
  select * from public.imersao_progresso_d2 where is_admin() order by visto_em desc;
$fn$;

revoke all on function public.admin_imersao_progresso_d2() from public;
grant execute on function public.admin_imersao_progresso_d2() to authenticated;
