-- =====================================================================
-- Pré-cadastro: a apostila passa a pedir e-mail e WhatsApp também
-- Projeto: Cadastro de Creators (mfrmnquvwwuxraqgemyh)
--
-- Acrescenta 2 colunas na imersao_progresso e troca a função de gravar
-- por uma versão que recebe os campos novos. Não toca em mais nada.
-- =====================================================================

alter table public.imersao_progresso add column if not exists email    text;
alter table public.imersao_progresso add column if not exists whatsapp text;

-- sai a versão antiga (6 campos) pra não ficarem duas iguais
drop function if exists public.imersao_salvar_progresso(text,text,text,jsonb,int,int);

create or replace function public.imersao_salvar_progresso(
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
  insert into imersao_progresso (arroba, nome, email, whatsapp, etapa, feitos, marcados, total)
  values (a, left(n,80), left(e,120), left(w,20), left(coalesce(p_etapa,''),8),
          coalesce(p_feitos,'[]'::jsonb), coalesce(p_marcados,0), coalesce(p_total,0))
  on conflict (arroba) do update set
    nome     = coalesce(excluded.nome,     imersao_progresso.nome),
    email    = coalesce(excluded.email,    imersao_progresso.email),
    whatsapp = coalesce(excluded.whatsapp, imersao_progresso.whatsapp),
    etapa    = excluded.etapa,
    feitos   = excluded.feitos,
    marcados = excluded.marcados,
    total    = excluded.total,
    visto_em = now();
end $fn$;

revoke all on function public.imersao_salvar_progresso(text,text,text,text,text,jsonb,int,int) from public;
grant execute on function public.imersao_salvar_progresso(text,text,text,text,text,jsonb,int,int) to anon, authenticated;
