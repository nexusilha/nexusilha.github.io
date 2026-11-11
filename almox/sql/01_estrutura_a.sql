SET check_function_bodies = false;

CREATE TYPE public.almox_bucket AS ENUM (
    'DISPONIVEL',
    'LAVANDERIA'
);
CREATE TYPE public.almox_papel AS ENUM (
    'GESTOR',
    'OPERADOR',
    'LEITURA'
);
CREATE TYPE public.almox_status_cobranca AS ENUM (
    'PENDENTE',
    'DESCONTADA',
    'PERDOADA',
    'CANCELADA'
);
CREATE TYPE public.almox_status_emprestimo AS ENUM (
    'ABERTO',
    'PARCIAL',
    'DEVOLVIDO',
    'BAIXADO',
    'CANCELADO'
);
CREATE TYPE public.almox_status_inventario AS ENUM (
    'ABERTO',
    'FINALIZADO',
    'CANCELADO'
);
CREATE TYPE public.almox_status_remessa AS ENUM (
    'ENVIADA',
    'RECEBIDA',
    'CANCELADA'
);
CREATE TYPE public.almox_tipo_mov AS ENUM (
    'ENTRADA_COMPRA',
    'ENTRADA_DEVOLUCAO',
    'ENTRADA_RETORNO_EMPRESTIMO',
    'ENTRADA_AJUSTE',
    'SAIDA_FUNCIONARIO',
    'SAIDA_EMPRESTIMO',
    'SAIDA_DESCARTE',
    'SAIDA_AJUSTE',
    'RETORNO_LAVANDERIA',
    'DESCARTE_LAVANDERIA'
);
CREATE TABLE public.almox_inventarios (
    id bigint NOT NULL,
    codigo text NOT NULL,
    unidade_id bigint,
    categoria_id bigint,
    descricao text,
    status public.almox_status_inventario DEFAULT 'ABERTO'::public.almox_status_inventario NOT NULL,
    iniciado_em timestamp with time zone DEFAULT now() NOT NULL,
    finalizado_em timestamp with time zone,
    usuario_id uuid
);
CREATE FUNCTION public.almox_abrir_inventario(p_categoria_id bigint DEFAULT NULL::bigint, p_descricao text DEFAULT NULL::text, p_unidade_id bigint DEFAULT NULL::bigint) RETURNS public.almox_inventarios
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare v_inv almox_inventarios%rowtype; v_uni text;
begin
  if not almox_opera_unidade(p_unidade_id) then raise exception 'Sem permissao nesta unidade.'; end if;
  if exists (select 1 from almox_inventarios where status='ABERTO' and unidade_id=p_unidade_id) then
    raise exception 'Ja existe um inventario aberto nesta unidade.';
  end if;
  select codigo into v_uni from almox_unidades where id = p_unidade_id;
  insert into almox_inventarios (codigo, unidade_id, categoria_id, descricao, usuario_id)
  values (almox_gerar_codigo('INV', coalesce(v_uni,'GER')), p_unidade_id, p_categoria_id, p_descricao, auth.uid())
  returning * into v_inv;
  insert into almox_inventario_itens (inventario_id, variacao_id, saldo_sistema)
  select v_inv.id, v.id, v.saldo
    from almox_variacoes v
    join almox_itens i on i.id = v.item_id
   where v.unidade_id = p_unidade_id
     and (p_categoria_id is null or i.categoria_id = p_categoria_id)
     -- ativo entra sempre; inativo entra se ainda houver peca
     and ( (v.ativo and i.ativo) or v.saldo <> 0 or v.saldo_lavanderia <> 0 );
  return v_inv;
end $$;
CREATE FUNCTION public.almox_admin_sistema() RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$ select coalesce((select admin_sistema from almox_usuarios
                        where id = auth.uid() and ativo), false) $$;
CREATE FUNCTION public.almox_ampliar_inventario(p_inventario_id bigint, p_categoria_id bigint DEFAULT NULL::bigint) RETURNS text
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare v_inv almox_inventarios%rowtype; v_n int;
begin
  select * into v_inv from almox_inventarios where id = p_inventario_id;
  if not found then raise exception 'Inventario nao encontrado.'; end if;
  if not almox_opera_unidade(v_inv.unidade_id) then raise exception 'Sem permissao nesta unidade.'; end if;
  if v_inv.status <> 'ABERTO' then raise exception 'Esta contagem ja foi encerrada.'; end if;
  insert into almox_inventario_itens (inventario_id, variacao_id, saldo_sistema)
  select v_inv.id, v.id, v.saldo
    from almox_variacoes v
    join almox_itens i on i.id = v.item_id
   where v.unidade_id = v_inv.unidade_id
     and (p_categoria_id is null or i.categoria_id = p_categoria_id)
     and ((v.ativo and i.ativo) or v.saldo <> 0 or v.saldo_lavanderia <> 0)
     and not exists (select 1 from almox_inventario_itens ii
                      where ii.inventario_id = v_inv.id and ii.variacao_id = v.id)
  on conflict do nothing;
  get diagnostics v_n = row_count;
  -- escopo: se entrou tudo, a contagem deixa de ser de uma categoria so
  if p_categoria_id is null then
    update almox_inventarios set categoria_id = null where id = p_inventario_id;
  elsif v_inv.categoria_id is not null and v_inv.categoria_id <> p_categoria_id then
    update almox_inventarios set categoria_id = null,
           descricao = coalesce(descricao || ' | ','') || 'escopo ampliado'
     where id = p_inventario_id;
  end if;
  return format('%s posicoes acrescentadas a contagem %s', v_n, v_inv.codigo);
end $$;
CREATE TABLE public.almox_usuarios (
    id uuid NOT NULL,
    nome text NOT NULL,
    email text,
    papel public.almox_papel DEFAULT 'LEITURA'::public.almox_papel NOT NULL,
    unidade_id bigint,
    ativo boolean DEFAULT true NOT NULL,
    criado_em timestamp with time zone DEFAULT now() NOT NULL,
    todas_unidades boolean DEFAULT false NOT NULL,
    admin_sistema boolean DEFAULT false NOT NULL
);
CREATE FUNCTION public.almox_atualizar_meu_nome(p_nome text) RETURNS public.almox_usuarios
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare v_u almox_usuarios%rowtype;
begin
  if auth.uid() is null then raise exception 'Sem sessao.'; end if;
  if length(btrim(coalesce(p_nome,''))) < 2 then
    raise exception 'Informe como voce quer ser chamado (minimo 2 caracteres).';
  end if;
  if length(btrim(p_nome)) > 60 then
    raise exception 'Nome muito longo (maximo 60 caracteres).';
  end if;
  update almox_usuarios set nome = btrim(p_nome)
   where id = auth.uid() and ativo
   returning * into v_u;
  if not found then raise exception 'Usuario sem acesso ativo.'; end if;
  return v_u;
end $$;
CREATE TABLE public.almox_cobrancas (
    id bigint NOT NULL,
    codigo text NOT NULL,
    unidade_id bigint,
    funcionario_id bigint NOT NULL,
    emprestimo_id bigint,
    variacao_id bigint,
    quantidade integer NOT NULL,
    valor_unitario numeric(12,2) NOT NULL,
    valor_total numeric(14,2) GENERATED ALWAYS AS (((quantidade)::numeric * valor_unitario)) STORED,
    motivo text NOT NULL,
    status public.almox_status_cobranca DEFAULT 'PENDENTE'::public.almox_status_cobranca NOT NULL,
    data timestamp with time zone DEFAULT now() NOT NULL,
    baixado_em timestamp with time zone,
    observacoes text,
    usuario_id uuid,
    CONSTRAINT almox_cobrancas_quantidade_check CHECK ((quantidade > 0)),
    CONSTRAINT almox_cobrancas_valor_unitario_check CHECK ((valor_unitario >= (0)::numeric))
);
CREATE FUNCTION public.almox_baixar_cobranca(p_cobranca_id bigint, p_status text, p_observacoes text DEFAULT NULL::text) RETURNS public.almox_cobrancas
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare v_cb almox_cobrancas%rowtype;
begin
  select * into v_cb from almox_cobrancas where id = p_cobranca_id;
  if not found then raise exception 'Cobranca nao encontrada.'; end if;
  if not almox_gestor_unidade(v_cb.unidade_id) then
    raise exception 'Apenas o gestor desta unidade baixa cobrancas.'; end if;
  if p_status not in ('DESCONTADA','PERDOADA','CANCELADA','PENDENTE') then raise exception 'Situacao invalida.'; end if;
  if p_status in ('PERDOADA','CANCELADA') and coalesce(btrim(p_observacoes),'') = '' then
    raise exception 'Informe a justificativa.'; end if;
  update almox_cobrancas set status = p_status::almox_status_cobranca,
         baixado_em = case when p_status='PENDENTE' then null else now() end,
         observacoes = coalesce(nullif(btrim(p_observacoes),''), observacoes)
   where id = p_cobranca_id returning * into v_cb;
  return v_cb;
end $$;
CREATE TABLE public.almox_emprestimos (
    id bigint NOT NULL,
    codigo text NOT NULL,
    unidade_id bigint,
    funcionario_id bigint NOT NULL,
    data_saida timestamp with time zone DEFAULT now() NOT NULL,
    previsao_devolucao date,
    status public.almox_status_emprestimo DEFAULT 'ABERTO'::public.almox_status_emprestimo NOT NULL,
    motivo text,
    observacoes text,
    recibo_assinado boolean DEFAULT false NOT NULL,
    assinado_em timestamp with time zone,
    usuario_id uuid,
    criado_em timestamp with time zone DEFAULT now() NOT NULL
);
CREATE FUNCTION public.almox_baixar_emprestimo(p_emprestimo_id bigint, p_motivo text, p_cobrar boolean DEFAULT true, p_valor_unitario numeric DEFAULT NULL::numeric) RETURNS public.almox_emprestimos
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare v_emp almox_emprestimos%rowtype; r record; v_falta int; v_valor numeric;
        v_padrao numeric; v_uni text;
begin
  select * into v_emp from almox_emprestimos where id = p_emprestimo_id;
  if not found then raise exception 'Emprestimo nao encontrado.'; end if;
  if not almox_opera_unidade(v_emp.unidade_id) then raise exception 'Sem permissao nesta unidade.'; end if;
  if coalesce(btrim(p_motivo),'') = '' then raise exception 'Informe o motivo da baixa.'; end if;
  if v_emp.status in ('DEVOLVIDO','BAIXADO') then raise exception 'Emprestimo ja encerrado.'; end if;
  select valor_num into v_padrao from almox_parametros
   where unidade_id = v_emp.unidade_id and chave = 'custo_extravio_uniforme';
  select codigo into v_uni from almox_unidades where id = v_emp.unidade_id;
  for r in select ei.*, nullif(i.custo_referencia,0) as custo_atual
             from almox_emprestimo_itens ei
             join almox_variacoes v on v.id = ei.variacao_id
             join almox_itens i on i.id = v.item_id
            where ei.emprestimo_id = p_emprestimo_id and ei.quantidade > ei.quantidade_devolvida loop
    v_falta := r.quantidade - r.quantidade_devolvida;
    -- prioridade: valor informado agora > valor congelado no recibo > custo atual > padrao
    v_valor := coalesce(p_valor_unitario, r.valor_unitario_reposicao, r.custo_atual, v_padrao, 0);
    insert into almox_movimentacoes (unidade_id, variacao_id, tipo, quantidade, funcionario_id,
      emprestimo_id, documento, justificativa, usuario_id)
    values (v_emp.unidade_id, r.variacao_id,'ENTRADA_RETORNO_EMPRESTIMO', v_falta,
            v_emp.funcionario_id, v_emp.id, v_emp.codigo,
            'Baixa do emprestimo ' || v_emp.codigo, auth.uid());
    insert into almox_movimentacoes (unidade_id, variacao_id, tipo, quantidade, funcionario_id,
      documento, justificativa, usuario_id)
    values (v_emp.unidade_id, r.variacao_id,'SAIDA_FUNCIONARIO', v_falta, v_emp.funcionario_id,
            v_emp.codigo, 'Baixa do emprestimo ' || v_emp.codigo || ': ' || p_motivo, auth.uid());
    update almox_emprestimo_itens set quantidade_devolvida = quantidade where id = r.id;
    if p_cobrar and v_valor > 0 then
      insert into almox_cobrancas (codigo, unidade_id, funcionario_id, emprestimo_id, variacao_id,
        quantidade, valor_unitario, motivo, usuario_id)
      values (almox_gerar_codigo('COB', coalesce(v_uni,'GER')), v_emp.unidade_id, v_emp.funcionario_id,
              v_emp.id, r.variacao_id, v_falta, v_valor,
              'Peca emprestada nao devolvida - ' || v_emp.codigo || ': ' || p_motivo, auth.uid());
    end if;
  end loop;
  update almox_emprestimos set status='BAIXADO',
         observacoes = coalesce(observacoes || ' | ','') || 'Baixa: ' || p_motivo
   where id = p_emprestimo_id returning * into v_emp;
  return v_emp;
end $$;
CREATE FUNCTION public.almox_cancelar_emprestimo(p_emprestimo_id bigint, p_motivo text) RETURNS public.almox_emprestimos
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare v_emp almox_emprestimos%rowtype; m record; v_disp int; v_lav int; v_n int := 0;
begin
  select * into v_emp from almox_emprestimos where id = p_emprestimo_id;
  if not found then raise exception 'Emprestimo nao encontrado.'; end if;
  if not almox_gestor_unidade(v_emp.unidade_id) then
    raise exception 'Apenas o gestor desta unidade pode cancelar emprestimo.';
  end if;
  if coalesce(btrim(p_motivo),'') = '' then
    raise exception 'Informe o motivo do cancelamento.';
  end if;
  if v_emp.status = 'CANCELADO' then raise exception 'Emprestimo ja cancelado.'; end if;
  if exists (select 1 from almox_cobrancas where emprestimo_id = p_emprestimo_id
              and status <> 'CANCELADA') then
    raise exception 'Ha cobranca vinculada a este emprestimo. Cancele a cobranca antes.';
  end if;
  -- estorna do mais recente para o mais antigo, para o saldo nunca ficar negativo
  for m in select * from almox_movimentacoes
            where emprestimo_id = p_emprestimo_id and cancelada = false
            order by id desc loop
    select saldo, saldo_lavanderia into v_disp, v_lav
      from almox_variacoes where id = m.variacao_id for update;
    if m.bucket = 'LAVANDERIA' then
      if v_lav < m.quantidade then
        raise exception 'A peca ja saiu da lavanderia. Conclua ou cancele o lote antes.';
      end if;
      update almox_variacoes set saldo_lavanderia = v_lav - m.quantidade, atualizado_em = now()
       where id = m.variacao_id;
    elsif almox_e_entrada(m.tipo) then
      if v_disp < m.quantidade then
        raise exception 'Saldo insuficiente para estornar o retorno da peca.';
      end if;
      update almox_variacoes set saldo = v_disp - m.quantidade, atualizado_em = now()
       where id = m.variacao_id;
    else
      update almox_variacoes set saldo = v_disp + m.quantidade, atualizado_em = now()
       where id = m.variacao_id;
    end if;
    update almox_movimentacoes
       set cancelada = true, cancelada_em = now(),
           motivo_cancelamento = 'Emprestimo cancelado: ' || p_motivo
     where id = m.id;
    v_n := v_n + 1;
  end loop;
  update almox_emprestimo_itens set quantidade_devolvida = 0 where emprestimo_id = p_emprestimo_id;
  update almox_emprestimos
     set status = 'CANCELADO',
         observacoes = coalesce(observacoes || ' | ','') || 'Cancelado: ' || p_motivo
   where id = p_emprestimo_id returning * into v_emp;
  return v_emp;
end $$;
CREATE FUNCTION public.almox_cancelar_movimentacao(p_id bigint, p_motivo text) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare m almox_movimentacoes%rowtype; v_disp int; v_lav int;
begin
  select * into m from almox_movimentacoes where id = p_id;
  if not found then raise exception 'Movimentacao % nao encontrada.', p_id; end if;
  if not almox_gestor_unidade(m.unidade_id) then
    raise exception 'Apenas o gestor desta unidade pode cancelar movimentacoes.';
  end if;
  if m.cancelada then raise exception 'Movimentacao ja cancelada.'; end if;
  if coalesce(btrim(p_motivo),'') = '' then raise exception 'Informe o motivo do cancelamento.'; end if;
  if m.emprestimo_id is not null then
    raise exception 'Movimentacao vinculada a emprestimo. Use a devolucao ou a baixa do emprestimo.';
  end if;
  if m.remessa_id is not null then
    raise exception 'Movimentacao vinculada a lote de lavanderia. Corrija pelo lote.';
  end if;
  select saldo, saldo_lavanderia into v_disp, v_lav
    from almox_variacoes where id = m.variacao_id for update;
  if m.tipo = 'RETORNO_LAVANDERIA' then
    if v_disp < m.quantidade then raise exception 'Estorno deixaria o disponivel negativo.'; end if;
    update almox_variacoes set saldo = v_disp - m.quantidade,
           saldo_lavanderia = v_lav + m.quantidade, atualizado_em = now() where id = m.variacao_id;
  elsif m.tipo = 'DESCARTE_LAVANDERIA' then
    update almox_variacoes set saldo_lavanderia = v_lav + m.quantidade, atualizado_em = now() where id = m.variacao_id;
  elsif m.bucket = 'LAVANDERIA' then
    if v_lav < m.quantidade then raise exception 'Estorno deixaria a lavanderia negativa.'; end if;
    update almox_variacoes set saldo_lavanderia = v_lav - m.quantidade, atualizado_em = now() where id = m.variacao_id;
  else
    if v_disp + (case when almox_e_entrada(m.tipo) then -m.quantidade else m.quantidade end) < 0 then
      raise exception 'Cancelamento deixaria o saldo negativo (disponivel %).', v_disp;
    end if;
    update almox_variacoes
       set saldo = v_disp + (case when almox_e_entrada(m.tipo) then -m.quantidade else m.quantidade end),
           atualizado_em = now() where id = m.variacao_id;
  end if;
  update almox_movimentacoes set cancelada = true, motivo_cancelamento = p_motivo,
         cancelada_em = now() where id = p_id;
end $$;
CREATE FUNCTION public.almox_carga_inicial(p_unidade_id bigint, p_itens jsonb, p_data date DEFAULT NULL::date) RETURNS text
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare it jsonb; v_q int; v_var bigint; v_org text; v_f bigint;
        v_data timestamptz; v_est int:=0; v_lav int:=0; v_pos int:=0;
begin
  if not almox_gestor_unidade(p_unidade_id) then
    raise exception 'Apenas o gestor desta unidade pode lancar saldo inicial.';
  end if;
  v_data := coalesce(p_data::timestamptz, now());
  for it in select * from jsonb_array_elements(p_itens) loop
    v_var := (it->>'variacao_id')::bigint;
    v_q   := (it->>'quantidade')::int;
    v_org := upper(coalesce(it->>'origem','ESTOQUE'));
    v_f   := nullif(it->>'funcionario_id','')::bigint;
    continue when v_q is null or v_q <= 0;
    if v_org = 'LAVANDERIA' then
      insert into almox_movimentacoes (unidade_id, variacao_id, tipo, bucket, quantidade,
        data, documento, justificativa, usuario_id)
      values (p_unidade_id, v_var, 'ENTRADA_DEVOLUCAO', 'LAVANDERIA', v_q, v_data,
              'SALDO-INICIAL', 'Saldo inicial: peca suja aguardando lavagem', auth.uid());
      v_lav := v_lav + v_q;
    elsif v_org = 'POSSE' then
      if v_f is null then raise exception 'Origem POSSE exige funcionario_id.'; end if;
      -- entra e sai na mesma data: o estoque nao infla e a posse fica registrada
      insert into almox_movimentacoes (unidade_id, variacao_id, tipo, quantidade,
        data, documento, justificativa, usuario_id)
      values (p_unidade_id, v_var, 'ENTRADA_AJUSTE', v_q, v_data,
              'SALDO-INICIAL', 'Saldo inicial: peca ja em posse do funcionario', auth.uid());
      insert into almox_movimentacoes (unidade_id, variacao_id, tipo, quantidade, funcionario_id,
        data, documento, justificativa, usuario_id)
      values (p_unidade_id, v_var, 'SAIDA_FUNCIONARIO', v_q, v_f, v_data,
              'SALDO-INICIAL', 'Saldo inicial: uniforme ja entregue antes do sistema', auth.uid());
      v_pos := v_pos + v_q;
    else
      insert into almox_movimentacoes (unidade_id, variacao_id, tipo, quantidade,
        data, documento, justificativa, usuario_id)
      values (p_unidade_id, v_var, 'ENTRADA_AJUSTE', v_q, v_data,
              'SALDO-INICIAL', 'Saldo inicial em estoque', auth.uid());
      v_est := v_est + v_q;
    end if;
  end loop;
  return format('Saldo inicial: %s no estoque, %s na lavanderia, %s em posse de funcionarios',
                v_est, v_lav, v_pos);
end $$;
CREATE FUNCTION public.almox_clonar_catalogo(p_origem bigint, p_destino bigint) RETURNS text
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare v_cat int; v_gra int; v_tam int; v_ite int; v_var int; v_dot int;
begin
  if p_origem = p_destino then raise exception 'Origem e destino iguais.'; end if;
  insert into almox_categorias (unidade_id, nome, cor, ordem, ativo)
  select p_destino, c.nome, c.cor, c.ordem, c.ativo from almox_categorias c
   where c.unidade_id = p_origem
  on conflict do nothing;
  get diagnostics v_cat = row_count;
  insert into almox_grades (unidade_id, nome, descricao, ativo)
  select p_destino, g.nome, g.descricao, g.ativo from almox_grades g
   where g.unidade_id = p_origem
  on conflict do nothing;
  get diagnostics v_gra = row_count;
  insert into almox_tamanhos (unidade_id, grade_id, rotulo, ordem, ativo)
  select p_destino, gd.id, t.rotulo, t.ordem, t.ativo
    from almox_tamanhos t
    join almox_grades go2 on go2.id = t.grade_id and go2.unidade_id = p_origem
    join almox_grades gd  on gd.unidade_id = p_destino and gd.nome = go2.nome
  on conflict do nothing;
  get diagnostics v_tam = row_count;
  insert into almox_itens (unidade_id, codigo, nome, categoria_id, grade_id, cor, descricao,
                           unidade_medida, epi, ca_epi, exige_devolucao, vida_util_meses,
                           custo_referencia, estoque_minimo, ativo, grupo_dotacao, foto_url)
  select p_destino, i.codigo, i.nome, cd.id, gd.id, i.cor, i.descricao,
         i.unidade_medida, i.epi, i.ca_epi, i.exige_devolucao, i.vida_util_meses,
         i.custo_referencia, i.estoque_minimo, i.ativo, i.grupo_dotacao, i.foto_url
    from almox_itens i
    join almox_grades go2 on go2.id = i.grade_id and go2.unidade_id = p_origem
    join almox_grades gd  on gd.unidade_id = p_destino and gd.nome = go2.nome
    left join almox_categorias co on co.id = i.categoria_id
    left join almox_categorias cd on cd.unidade_id = p_destino and cd.nome = co.nome
   where i.unidade_id = p_origem
  on conflict do nothing;
  get diagnostics v_ite = row_count;
  insert into almox_variacoes (unidade_id, item_id, tamanho_id)
  select p_destino, i.id, t.id
    from almox_itens i
    join almox_tamanhos t on t.grade_id = i.grade_id and t.ativo
   where i.unidade_id = p_destino and i.ativo
  on conflict do nothing;
  get diagnostics v_var = row_count;
  insert into almox_dotacoes (unidade_id, grupo, cargo, setor, quantidade_minima, observacoes, ativo)
  select p_destino, d.grupo, d.cargo, d.setor, d.quantidade_minima, d.observacoes, d.ativo
    from almox_dotacoes d where d.unidade_id = p_origem
  on conflict do nothing;
  get diagnostics v_dot = row_count;
  insert into almox_parametros (unidade_id, chave, valor_num, valor_txt, descricao)
  select p_destino, p.chave, p.valor_num, p.valor_txt, p.descricao
    from almox_parametros p where p.unidade_id = p_origem
  on conflict do nothing;
  return format('%s categorias, %s grades, %s tamanhos, %s itens, %s posicoes, %s regras',
                v_cat, v_gra, v_tam, v_ite, v_var, v_dot);
end $$;
CREATE TABLE public.almox_unidades (
    id bigint NOT NULL,
    codigo text NOT NULL,
    nome text NOT NULL,
    ativo boolean DEFAULT true NOT NULL,
    criado_em timestamp with time zone DEFAULT now() NOT NULL,
    cnpj text,
    endereco text,
    responsavel_epi text,
    razao_social text
);
CREATE FUNCTION public.almox_criar_unidade(p_codigo text, p_nome text, p_copiar_de bigint DEFAULT NULL::bigint) RETURNS public.almox_unidades
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare v_u almox_unidades%rowtype;
begin
  if not almox_admin_sistema() then
    raise exception 'Apenas o administrador do sistema abre unidade nova.';
  end if;
  insert into almox_unidades (codigo, nome) values (upper(btrim(p_codigo)), btrim(p_nome))
  returning * into v_u;
  if p_copiar_de is not null then perform almox_clonar_catalogo(p_copiar_de, v_u.id); end if;
  insert into almox_acessos (usuario_id, unidade_id, papel)
  values (auth.uid(), v_u.id, 'GESTOR') on conflict do nothing;
  return v_u;
end $$;
CREATE TABLE public.almox_funcionarios (
    id bigint NOT NULL,
    matricula text,
    nome text NOT NULL,
    cpf text,
    cargo text,
    setor text,
    unidade_id bigint NOT NULL,
    data_admissao date,
    observacoes text,
    ativo boolean DEFAULT true NOT NULL,
    criado_em timestamp with time zone DEFAULT now() NOT NULL,
    vinculo text DEFAULT 'EFETIVO'::text NOT NULL,
    data_desligamento date,
    lideranca boolean DEFAULT false NOT NULL,
    termo_assinado_em date,
    funcao_id bigint,
    nivel text,
    vinculo_ate date,
    rg text,
    rg_orgao text,
    CONSTRAINT ck_almox_func_nivel CHECK (((nivel IS NULL) OR (nivel = ANY (ARRAY['JR'::text, 'MR'::text, 'SR'::text])))),
    CONSTRAINT ck_almox_func_vinculo CHECK ((vinculo = ANY (ARRAY['ADAPTACAO'::text, 'EXPERIENCIA'::text, 'EFETIVO'::text, 'INTERMITENTE'::text, 'APRENDIZ'::text])))
);
CREATE FUNCTION public.almox_desligar_funcionario(p_funcionario_id bigint, p_data date DEFAULT CURRENT_DATE, p_observacoes text DEFAULT NULL::text) RETURNS public.almox_funcionarios
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare v_f almox_funcionarios%rowtype;
begin
  select * into v_f from almox_funcionarios where id = p_funcionario_id;
  if not found then raise exception 'Funcionario nao encontrado.'; end if;
  if not almox_gestor_unidade(v_f.unidade_id) then raise exception 'Sem permissao nesta unidade.'; end if;
  update almox_funcionarios set ativo=false, data_desligamento=coalesce(p_data,current_date),
    observacoes = case when coalesce(btrim(p_observacoes),'')='' then observacoes
                       else coalesce(observacoes||' | ','')||p_observacoes end
   where id = p_funcionario_id returning * into v_f;
  return v_f;
end $$;
CREATE FUNCTION public.almox_devolver_emprestimo(p_emprestimo_id bigint, p_itens jsonb, p_observacoes text DEFAULT NULL::text, p_para_lavanderia boolean DEFAULT true) RETURNS public.almox_emprestimos
    LANGUAGE plpgsql
    AS $$
declare
  v_emp almox_emprestimos%rowtype;
  it jsonb; v_it almox_emprestimo_itens%rowtype; v_q int; v_pend int; v_dev int;
begin
  select * into v_emp from almox_emprestimos where id = p_emprestimo_id;
  if not found then raise exception 'Emprestimo nao encontrado.'; end if;
  if v_emp.status in ('DEVOLVIDO','BAIXADO') then
    raise exception 'Emprestimo % ja encerrado.', v_emp.codigo;
  end if;
  for it in select * from jsonb_array_elements(p_itens) loop
    v_q := (it->>'quantidade')::int;
    continue when v_q is null or v_q <= 0;
    select * into v_it from almox_emprestimo_itens
     where id = (it->>'emprestimo_item_id')::bigint and emprestimo_id = p_emprestimo_id;
    if not found then raise exception 'Item do emprestimo nao encontrado.'; end if;
    if v_it.quantidade_devolvida + v_q > v_it.quantidade then
      raise exception 'Devolucao maior que o emprestado (emprestado %, ja devolvido %).',
        v_it.quantidade, v_it.quantidade_devolvida;
    end if;
    update almox_emprestimo_itens
       set quantidade_devolvida = quantidade_devolvida + v_q where id = v_it.id;
    insert into almox_movimentacoes
      (unidade_id, variacao_id, tipo, bucket, quantidade, funcionario_id, emprestimo_id,
       documento, justificativa, observacoes, usuario_id)
    values
      (v_emp.unidade_id, v_it.variacao_id, 'ENTRADA_RETORNO_EMPRESTIMO',
       case when p_para_lavanderia then 'LAVANDERIA'::almox_bucket else 'DISPONIVEL'::almox_bucket end,
       v_q, v_emp.funcionario_id, v_emp.id, v_emp.codigo,
       'Retorno do emprestimo ' || v_emp.codigo ||
         case when p_para_lavanderia then ' - peca suja, foi para lavanderia' else ' - peca limpa, direto ao estoque' end,
       p_observacoes, auth.uid());
  end loop;
  select coalesce(sum(quantidade - quantidade_devolvida),0), coalesce(sum(quantidade_devolvida),0)
    into v_pend, v_dev from almox_emprestimo_itens where emprestimo_id = p_emprestimo_id;
  update almox_emprestimos
     set status = case when v_pend = 0 then 'DEVOLVIDO'::almox_status_emprestimo
                       when v_dev  > 0 then 'PARCIAL'::almox_status_emprestimo
                       else 'ABERTO'::almox_status_emprestimo end
   where id = p_emprestimo_id returning * into v_emp;
  return v_emp;
end $$;
CREATE FUNCTION public.almox_e_entrada(p_tipo public.almox_tipo_mov) RETURNS boolean
    LANGUAGE sql IMMUTABLE
    AS $$
  select p_tipo in ('ENTRADA_COMPRA','ENTRADA_DEVOLUCAO','ENTRADA_RETORNO_EMPRESTIMO',
                    'ENTRADA_AJUSTE','RETORNO_LAVANDERIA');
$$;
CREATE TABLE public.almox_remessas_lavanderia (
    id bigint NOT NULL,
    codigo text NOT NULL,
    unidade_id bigint,
    fornecedor_id bigint,
    status public.almox_status_remessa DEFAULT 'ENVIADA'::public.almox_status_remessa NOT NULL,
    data_envio timestamp with time zone DEFAULT now() NOT NULL,
    data_retorno timestamp with time zone,
    custo numeric(12,2),
    observacoes text,
    usuario_id uuid,
    criado_em timestamp with time zone DEFAULT now() NOT NULL,
    responsavel text,
    local text DEFAULT 'Lavanderia interna'::text
);
CREATE FUNCTION public.almox_enviar_lavanderia(p_itens jsonb, p_responsavel text DEFAULT NULL::text, p_observacoes text DEFAULT NULL::text, p_unidade_id bigint DEFAULT NULL::bigint, p_local text DEFAULT 'Lavanderia interna'::text) RETURNS public.almox_remessas_lavanderia
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare v_rem almox_remessas_lavanderia%rowtype; it jsonb; v_uni text; v_disp int; v_nome text; v_q int;
begin
  if not almox_opera_unidade(p_unidade_id) then raise exception 'Sem permissao nesta unidade.'; end if;
  if jsonb_array_length(coalesce(p_itens,'[]'::jsonb)) = 0 then raise exception 'Inclua ao menos uma peca.'; end if;
  select codigo into v_uni from almox_unidades where id = p_unidade_id;
  insert into almox_remessas_lavanderia (codigo, unidade_id, responsavel, local, observacoes, usuario_id)
  values (almox_gerar_codigo('LAV', coalesce(v_uni,'GER')), p_unidade_id,
          nullif(btrim(coalesce(p_responsavel,'')),''), coalesce(nullif(btrim(p_local),''),'Lavanderia interna'),
          p_observacoes, auth.uid()) returning * into v_rem;
  for it in select * from jsonb_array_elements(p_itens) loop
    v_q := (it->>'quantidade')::int;
    continue when v_q is null or v_q <= 0;
    select l.aguardando_envio, l.item || ' ' || l.tamanho into v_disp, v_nome
      from almox_vw_lavanderia l where l.variacao_id = (it->>'variacao_id')::bigint;
    if v_disp is null or v_disp < v_q then
      raise exception 'So ha % peca(s) de % aguardando lavagem; tentou enviar %.', coalesce(v_disp,0), coalesce(v_nome,'?'), v_q;
    end if;
    insert into almox_remessa_itens (remessa_id, variacao_id, quantidade)
    values (v_rem.id, (it->>'variacao_id')::bigint, v_q);
  end loop;
  return v_rem;
end $$;
CREATE FUNCTION public.almox_finalizar_inventario(p_inventario_id bigint) RETURNS TABLE(variacao_id bigint, diferenca integer)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare v_inv almox_inventarios%rowtype; r record; v_dif int; v_saldo int;
begin
  select * into v_inv from almox_inventarios where id = p_inventario_id;
  if not found then raise exception 'Inventario nao encontrado.'; end if;
  if not almox_opera_unidade(v_inv.unidade_id) then raise exception 'Sem permissao nesta unidade.'; end if;
  if v_inv.status <> 'ABERTO' then raise exception 'Inventario ja encerrado.'; end if;
  for r in select * from almox_inventario_itens
            where inventario_id = p_inventario_id and saldo_contado is not null loop
    select saldo into v_saldo from almox_variacoes where id = r.variacao_id;
    v_dif := r.saldo_contado - v_saldo;
    continue when v_dif = 0;
    insert into almox_movimentacoes
      (unidade_id, variacao_id, tipo, quantidade, inventario_id, documento, justificativa, usuario_id)
    values (v_inv.unidade_id, r.variacao_id,
      case when v_dif > 0 then 'ENTRADA_AJUSTE'::almox_tipo_mov else 'SAIDA_AJUSTE'::almox_tipo_mov end,
      abs(v_dif), v_inv.id, v_inv.codigo,
      'Ajuste do inventario ' || v_inv.codigo || ' (sistema ' || v_saldo || ' / contado ' || r.saldo_contado || ')',
      auth.uid());
    variacao_id := r.variacao_id; diferenca := v_dif; return next;
  end loop;
  update almox_inventarios set status='FINALIZADO', finalizado_em=now() where id = p_inventario_id;
end $$;
CREATE FUNCTION public.almox_fn_aplicar_mov() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare v_disp int; v_lav int; v_delta int; v_nome text; v_uni bigint; v_uni_f bigint;
begin
  select v.saldo, v.saldo_lavanderia, v.unidade_id into v_disp, v_lav, v_uni
    from almox_variacoes v where v.id = new.variacao_id for update;
  if v_disp is null then raise exception 'Variacao % nao encontrada.', new.variacao_id; end if;
  if new.unidade_id is null then new.unidade_id := v_uni;
  elsif new.unidade_id <> v_uni then
    raise exception 'A peca pertence a outra unidade. Lancamento recusado.';
  end if;
  if new.funcionario_id is not null then
    select unidade_id into v_uni_f from almox_funcionarios where id = new.funcionario_id;
    if v_uni_f is null then raise exception 'Funcionario nao encontrado.'; end if;
    if v_uni_f <> v_uni then
      raise exception 'O funcionario e de outra unidade. Lancamento recusado.';
    end if;
  end if;
  select i.nome || ' ' || coalesce(t.rotulo,'') into v_nome
    from almox_variacoes v
    join almox_itens i on i.id = v.item_id
    left join almox_tamanhos t on t.id = v.tamanho_id
   where v.id = new.variacao_id;
  if new.tipo = 'RETORNO_LAVANDERIA' then
    if v_lav < new.quantidade then
      raise exception 'Ha apenas % peca(s) de % na lavanderia; tentou retornar %.', v_lav, v_nome, new.quantidade;
    end if;
    new.bucket := 'DISPONIVEL';
    new.saldo_anterior := v_disp; new.saldo_posterior := v_disp + new.quantidade;
    update almox_variacoes set saldo = v_disp + new.quantidade,
           saldo_lavanderia = v_lav - new.quantidade, atualizado_em = now() where id = new.variacao_id;
  elsif new.tipo = 'DESCARTE_LAVANDERIA' then
    if v_lav < new.quantidade then
      raise exception 'Ha apenas % peca(s) de % na lavanderia; tentou descartar %.', v_lav, v_nome, new.quantidade;
    end if;
    new.bucket := 'LAVANDERIA';
    new.saldo_anterior := v_lav; new.saldo_posterior := v_lav - new.quantidade;
    update almox_variacoes set saldo_lavanderia = v_lav - new.quantidade, atualizado_em = now()
     where id = new.variacao_id;
  elsif new.bucket = 'LAVANDERIA' then
    if not almox_e_entrada(new.tipo) then
      raise exception 'Saida direta da lavanderia nao e permitida. Use retorno limpo ou descarte.';
    end if;
    new.saldo_anterior := v_lav; new.saldo_posterior := v_lav + new.quantidade;
    update almox_variacoes set saldo_lavanderia = v_lav + new.quantidade, atualizado_em = now()
     where id = new.variacao_id;
  else
    v_delta := case when almox_e_entrada(new.tipo) then new.quantidade else -new.quantidade end;
    if v_disp + v_delta < 0 then
      raise exception 'Saldo insuficiente de % : disponivel %, solicitado %.', v_nome, v_disp, new.quantidade;
    end if;
    new.saldo_anterior := v_disp; new.saldo_posterior := v_disp + v_delta;
    update almox_variacoes set saldo = v_disp + v_delta, atualizado_em = now() where id = new.variacao_id;
  end if;
  return new;
end $$;
CREATE FUNCTION public.almox_fn_guarda_usuario() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
begin
  if auth.uid() is null or almox_admin_sistema() then return new; end if;
  if new.admin_sistema is distinct from old.admin_sistema then
    raise exception 'Somente o administrador do sistema concede esse acesso.';
  end if;
  return new;
end $$;
CREATE FUNCTION public.almox_fn_novo_usuario() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare v_primeiro boolean;
begin
  select not exists (select 1 from almox_usuarios) into v_primeiro;
  insert into almox_usuarios (id, nome, email, papel, ativo, admin_sistema)
  values (new.id, coalesce(new.raw_user_meta_data->>'nome', split_part(new.email,'@',1)),
          new.email, 'LEITURA', true, v_primeiro)
  on conflict (id) do nothing;
  if v_primeiro then
    insert into almox_acessos (usuario_id, unidade_id, papel)
    select new.id, id, 'GESTOR' from almox_unidades;
  end if;
  return new;
end $$;
CREATE FUNCTION public.almox_fn_propaga_funcao() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin
  if new.nome is distinct from old.nome or new.setor is distinct from old.setor then
    update almox_funcionarios set cargo = new.nome, setor = new.setor
     where funcao_id = new.id;
  end if;
  return new;
end $$;
CREATE FUNCTION public.almox_fn_sku() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
declare v_item text; v_tam text; v_uni text;
begin
  if new.sku is null or btrim(new.sku) = '' then
    select codigo into v_uni from almox_unidades where id = new.unidade_id;
    select coalesce(i.codigo, 'IT' || lpad(i.id::text, 4, '0')) into v_item
      from almox_itens i where i.id = new.item_id;
    select t.rotulo into v_tam from almox_tamanhos t where t.id = new.tamanho_id;
    new.sku := coalesce(v_uni,'GER') || '-' || v_item || '-' ||
               coalesce(regexp_replace(upper(v_tam), '[^A-Z0-9]', '', 'g'), 'U');
  end if;
  return new;
end $$;
CREATE FUNCTION public.almox_fn_sync_funcao() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
declare v_nome text; v_setor text; v_uni bigint;
begin
  if new.funcao_id is not null then
    select nome, setor, unidade_id into v_nome, v_setor, v_uni
      from almox_funcoes where id = new.funcao_id;
    if v_nome is null then raise exception 'Funcao nao encontrada.'; end if;
    if v_uni <> new.unidade_id then raise exception 'Funcao pertence a outra unidade.'; end if;
    new.setor := v_setor;
    new.cargo := v_nome;
  end if;
  return new;
end $$;
CREATE FUNCTION public.almox_fn_valida_item_emprestimo() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
declare v_uni_e bigint; v_uni_v bigint;
begin
  select unidade_id into v_uni_e from almox_emprestimos where id = new.emprestimo_id;
  select unidade_id into v_uni_v from almox_variacoes where id = new.variacao_id;
  if v_uni_e is distinct from v_uni_v then
    raise exception 'A peca e de outra unidade.';
  end if;
  return new;
end $$;
CREATE FUNCTION public.almox_fn_valida_setor() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin
  if new.setor is not null and not exists (
      select 1 from almox_setores s
       where s.unidade_id = new.unidade_id and s.nome = new.setor) then
    raise exception 'Setor "%" nao existe nesta unidade.', new.setor;
  end if;
  return new;
end $$;
CREATE FUNCTION public.almox_fn_valida_unidade_funcionario() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
declare v_uni_f bigint;
begin
  select unidade_id into v_uni_f from almox_funcionarios where id = new.funcionario_id;
  if v_uni_f is null then raise exception 'Funcionario nao encontrado.'; end if;
  if new.unidade_id is null then new.unidade_id := v_uni_f;
  elsif v_uni_f <> new.unidade_id then
    raise exception 'O funcionario e de outra unidade.';
  end if;
  return new;
end $$;
CREATE FUNCTION public.almox_fn_valida_variacao() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
declare v_uni bigint;
begin
  select unidade_id into v_uni from almox_itens where id = new.item_id;
  if v_uni is distinct from new.unidade_id then
    raise exception 'Item pertence a outra unidade.';
  end if;
  return new;
end $$;
CREATE FUNCTION public.almox_gerar_codigo(p_prefixo text, p_unidade text DEFAULT 'VIX'::text) RETURNS text
    LANGUAGE plpgsql
    AS $$
declare
  v_dia   text := to_char(now() at time zone 'America/Sao_Paulo', 'YYMMDD');
  v_chave text := upper(p_prefixo) || '-' || upper(p_unidade) || '-' || v_dia;
  v_n     int;
begin
  insert into almox_contadores (chave, valor) values (v_chave, 1)
  on conflict (chave) do update set valor = almox_contadores.valor + 1
  returning valor into v_n;
  return v_chave || '-' || v_n;
end $$;
CREATE FUNCTION public.almox_gestor_unidade(p_unidade_id bigint) RETURNS boolean
    LANGUAGE sql STABLE
    AS $$ select almox_papel_unidade(p_unidade_id) = 'GESTOR' $$;
CREATE FUNCTION public.almox_opera_unidade(p_unidade_id bigint) RETURNS boolean
    LANGUAGE sql STABLE
    AS $$ select almox_papel_unidade(p_unidade_id) in ('GESTOR','OPERADOR') $$;
CREATE FUNCTION public.almox_papel_unidade(p_unidade_id bigint) RETURNS text
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  select coalesce((select a.papel::text
                     from almox_acessos a
                     join almox_usuarios u on u.id = a.usuario_id
                    where a.usuario_id = auth.uid() and a.unidade_id = p_unidade_id
                      and a.ativo and u.ativo), 'NENHUM')
$$;
CREATE FUNCTION public.almox_pode_ler() RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$ select exists (select 1 from almox_acessos a join almox_usuarios u on u.id = a.usuario_id
                      where a.usuario_id = auth.uid() and a.ativo and u.ativo) $$;
CREATE FUNCTION public.almox_reativar_funcionario(p_funcionario_id bigint) RETURNS public.almox_funcionarios
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare v_f almox_funcionarios%rowtype;
begin
  select * into v_f from almox_funcionarios where id = p_funcionario_id;
  if not found then raise exception 'Funcionario nao encontrado.'; end if;
  if not almox_gestor_unidade(v_f.unidade_id) then raise exception 'Sem permissao nesta unidade.'; end if;
  update almox_funcionarios set ativo=true, data_desligamento=null
   where id = p_funcionario_id returning * into v_f;
  return v_f;
end $$;
CREATE FUNCTION public.almox_recalcular_saldos(p_unidade_id bigint) RETURNS TABLE(variacao_id bigint, saldo_antigo integer, saldo_novo integer, lav_antigo integer, lav_novo integer)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
begin
  if not almox_gestor_unidade(p_unidade_id) then
    raise exception 'Apenas o gestor desta unidade pode recalcular saldos.';
  end if;
  return query
  with calc as (
    select v.id, v.saldo as d_ant, v.saldo_lavanderia as l_ant,
      coalesce(sum(case when m.cancelada then 0
        when m.tipo = 'RETORNO_LAVANDERIA' then m.quantidade
        when m.tipo = 'DESCARTE_LAVANDERIA' then 0
        when m.bucket = 'LAVANDERIA' then 0
        when almox_e_entrada(m.tipo) then m.quantidade else -m.quantidade end),0)::int as d_novo,
      coalesce(sum(case when m.cancelada then 0
        when m.tipo in ('RETORNO_LAVANDERIA','DESCARTE_LAVANDERIA') then -m.quantidade
        when m.bucket = 'LAVANDERIA' and almox_e_entrada(m.tipo) then m.quantidade
        else 0 end),0)::int as l_novo
      from almox_variacoes v
      left join almox_movimentacoes m on m.variacao_id = v.id
     where v.unidade_id = p_unidade_id
     group by v.id, v.saldo, v.saldo_lavanderia
  ), upd as (
    update almox_variacoes v set saldo = c.d_novo, saldo_lavanderia = c.l_novo, atualizado_em = now()
      from calc c where c.id = v.id and (c.d_ant <> c.d_novo or c.l_ant <> c.l_novo)
      returning v.id, c.d_ant, c.d_novo, c.l_ant, c.l_novo
  ) select u.id, u.d_ant, u.d_novo, u.l_ant, u.l_novo from upd u;
end $$;
