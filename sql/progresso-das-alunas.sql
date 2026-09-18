-- =====================================================================
-- Acompanhar o progresso das alunas na apostila da Imersão
-- Projeto: Cadastro de Creators (mfrmnquvwwuxraqgemyh)
--
-- É 100% ADITIVO: cria 1 tabela nova e 2 funções novas.
-- Não altera, não apaga e não toca em nenhuma tabela, função
-- ou policy que já existe no banco.
-- =====================================================================

-- 1. A tabela: uma linha por aluna
create table if not exists public.imersao_progresso (
  id        bigserial primary key,
  arroba    text not null unique,                    -- @ do instagram, normalizado
  nome      text,
  etapa     text,                                     -- última etapa aberta (e1..e16)
  feitos    jsonb not null default '[]'::jsonb,       -- quais checkpoints ela marcou
  marcados  int  not null default 0,
  total     int  not null default 0,
  criado_em timestamptz not null default now(),
  visto_em  timestamptz not null default now()
);

-- 2. Tranca: ninguém alcança a tabela direto. Só a Lara lê.
alter table public.imersao_progresso enable row level security;

drop policy if exists imersao_progresso_admin on public.imersao_progresso;
create policy imersao_progresso_admin on public.imersao_progresso
  for all to authenticated using (is_admin()) with check (is_admin());

-- 3. A porta de entrada da aluna: só essa função escreve, e só o que é dela.
--    Sem select, sem delete, sem alcançar a linha de ninguém.
create or replace function public.imersao_salvar_progresso(
  p_arroba text, p_nome text, p_etapa text, p_feitos jsonb, p_marcados int, p_total int
) returns void language plpgsql security definer set search_path = public as $fn$
declare a text; n text;
begin
  a := lower(regexp_replace(coalesce(p_arroba,''), '[^a-zA-Z0-9._]', '', 'g'));
  if a = '' or length(a) > 40 then return; end if;
  n := nullif(trim(coalesce(p_nome,'')),'');
  insert into imersao_progresso (arroba, nome, etapa, feitos, marcados, total)
  values (a, left(n,80), left(coalesce(p_etapa,''),8),
          coalesce(p_feitos,'[]'::jsonb), coalesce(p_marcados,0), coalesce(p_total,0))
  on conflict (arroba) do update set
    nome     = coalesce(excluded.nome, imersao_progresso.nome),
    etapa    = excluded.etapa,
    feitos   = excluded.feitos,
    marcados = excluded.marcados,
    total    = excluded.total,
    visto_em = now();
end $fn$;

revoke all on function public.imersao_salvar_progresso(text,text,text,jsonb,int,int) from public;
grant execute on function public.imersao_salvar_progresso(text,text,text,jsonb,int,int) to anon, authenticated;

-- 4. A leitura da Lara, no admin
create or replace function public.admin_imersao_progresso()
returns setof public.imersao_progresso language sql security definer set search_path = public as $fn2$
  select * from public.imersao_progresso where is_admin() order by visto_em desc;
$fn2$;

grant execute on function public.admin_imersao_progresso() to authenticated;
