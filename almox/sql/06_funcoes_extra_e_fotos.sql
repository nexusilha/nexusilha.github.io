SET check_function_bodies = false;
CREATE FUNCTION public.almox_excluir_cobranca(p_cobranca_id bigint, p_motivo text) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare v_cb almox_cobrancas%rowtype;
begin
  select * into v_cb from almox_cobrancas where id = p_cobranca_id;
  if not found then raise exception 'Cobranca nao encontrada.'; end if;
  if not almox_gestor_unidade(v_cb.unidade_id) then
    raise exception 'Apenas o gestor desta unidade pode excluir cobranca.';
  end if;
  if coalesce(btrim(p_motivo),'') = '' then raise exception 'Informe o motivo.'; end if;
  if v_cb.status = 'DESCONTADA' then
    raise exception 'Cobranca ja descontada em folha nao pode ser excluida. Registre o estorno com o RH.';
  end if;
  delete from almox_cobrancas where id = p_cobranca_id;
end $$;

CREATE FUNCTION public.almox_reiniciar_unidade(p_unidade_id bigint, p_confirmacao text) RETURNS text
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare v_cod text; v_mov int; v_emp int; v_inv int; v_rem int; v_cob int;
begin
  select codigo into v_cod from almox_unidades where id = p_unidade_id;
  if v_cod is null then raise exception 'Unidade nao encontrada.'; end if;
  if not almox_gestor_unidade(p_unidade_id) then
    raise exception 'Apenas o gestor desta unidade pode reiniciar a operacao.';
  end if;
  if upper(btrim(coalesce(p_confirmacao,''))) <> upper(v_cod) then
    raise exception 'Confirmacao invalida: digite o codigo da unidade (%).', v_cod;
  end if;

  select count(*) into v_mov from almox_movimentacoes where unidade_id = p_unidade_id;
  select count(*) into v_emp from almox_emprestimos   where unidade_id = p_unidade_id;
  select count(*) into v_inv from almox_inventarios   where unidade_id = p_unidade_id;
  select count(*) into v_rem from almox_remessas_lavanderia where unidade_id = p_unidade_id;
  select count(*) into v_cob from almox_cobrancas     where unidade_id = p_unidade_id;

  delete from almox_cobrancas    where unidade_id = p_unidade_id;
  delete from almox_movimentacoes where unidade_id = p_unidade_id;
  delete from almox_emprestimo_itens ei using almox_emprestimos e
   where e.id = ei.emprestimo_id and e.unidade_id = p_unidade_id;
  delete from almox_emprestimos  where unidade_id = p_unidade_id;
  delete from almox_inventario_itens ii using almox_inventarios i
   where i.id = ii.inventario_id and i.unidade_id = p_unidade_id;
  delete from almox_inventarios  where unidade_id = p_unidade_id;
  delete from almox_remessa_itens ri using almox_remessas_lavanderia r
   where r.id = ri.remessa_id and r.unidade_id = p_unidade_id;
  delete from almox_remessas_lavanderia where unidade_id = p_unidade_id;
  delete from almox_contadores where chave like '%-' || v_cod || '-%';

  update almox_variacoes set saldo = 0, saldo_lavanderia = 0, atualizado_em = now()
   where unidade_id = p_unidade_id;
  update almox_funcionarios set termo_assinado_em = null where unidade_id = p_unidade_id;

  return format('%s zerada: %s movimentacoes, %s emprestimos, %s inventarios, %s lotes, %s cobrancas apagados',
                v_cod, v_mov, v_emp, v_inv, v_rem, v_cob);
end $$;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('uniformes','uniformes', true, 5242880, '{image/jpeg,image/png,image/webp,image/avif}')
on conflict (id) do nothing;
CREATE POLICY almox_fotos_envio ON storage.objects FOR INSERT TO authenticated WITH CHECK (((bucket_id = 'uniformes'::text) AND public.almox_pode_ler()));
CREATE POLICY almox_fotos_leitura ON storage.objects FOR SELECT USING ((bucket_id = 'uniformes'::text));
CREATE POLICY almox_fotos_remocao ON storage.objects FOR DELETE TO authenticated USING (((bucket_id = 'uniformes'::text) AND public.almox_pode_ler()));
CREATE POLICY almox_fotos_troca ON storage.objects FOR UPDATE TO authenticated USING (((bucket_id = 'uniformes'::text) AND public.almox_pode_ler())) WITH CHECK (((bucket_id = 'uniformes'::text) AND public.almox_pode_ler()));
