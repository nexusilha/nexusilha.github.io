SET check_function_bodies = false;

CREATE FUNCTION public.almox_receber_lavanderia(p_remessa_id bigint, p_itens jsonb, p_custo numeric DEFAULT NULL::numeric, p_observacoes text DEFAULT NULL::text) RETURNS public.almox_remessas_lavanderia
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare v_rem almox_remessas_lavanderia%rowtype; it jsonb; v_it almox_remessa_itens%rowtype;
        v_ret int; v_con int; v_pend int;
begin
  select * into v_rem from almox_remessas_lavanderia where id = p_remessa_id;
  if not found then raise exception 'Lote nao encontrado.'; end if;
  if not almox_opera_unidade(v_rem.unidade_id) then raise exception 'Sem permissao nesta unidade.'; end if;
  if v_rem.status <> 'ENVIADA' then raise exception 'Lote % ja encerrado.', v_rem.codigo; end if;
  for it in select * from jsonb_array_elements(p_itens) loop
    v_ret := coalesce((it->>'retornadas')::int,0); v_con := coalesce((it->>'condenadas')::int,0);
    continue when v_ret = 0 and v_con = 0;
    select * into v_it from almox_remessa_itens where id=(it->>'remessa_item_id')::bigint and remessa_id=p_remessa_id;
    if not found then raise exception 'Item do lote nao encontrado.'; end if;
    if v_it.quantidade_retornada + v_it.quantidade_condenada + v_ret + v_con > v_it.quantidade then
      raise exception 'Baixa maior que o enviado.'; end if;
    if v_ret > 0 then
      insert into almox_movimentacoes (unidade_id, variacao_id, tipo, quantidade, remessa_id, documento, justificativa, usuario_id)
      values (v_rem.unidade_id, v_it.variacao_id,'RETORNO_LAVANDERIA', v_ret, v_rem.id, v_rem.codigo,
              'Retorno limpo do lote ' || v_rem.codigo, auth.uid());
    end if;
    if v_con > 0 then
      insert into almox_movimentacoes (unidade_id, variacao_id, tipo, quantidade, remessa_id, documento, justificativa, usuario_id)
      values (v_rem.unidade_id, v_it.variacao_id,'DESCARTE_LAVANDERIA', v_con, v_rem.id, v_rem.codigo,
              'Peca condenada na lavagem - lote ' || v_rem.codigo, auth.uid());
    end if;
    update almox_remessa_itens set quantidade_retornada = quantidade_retornada + v_ret,
           quantidade_condenada = quantidade_condenada + v_con where id = v_it.id;
  end loop;
  select coalesce(sum(quantidade - quantidade_retornada - quantidade_condenada),0) into v_pend
    from almox_remessa_itens where remessa_id = p_remessa_id;
  update almox_remessas_lavanderia
     set status = case when v_pend=0 then 'RECEBIDA'::almox_status_remessa else 'ENVIADA'::almox_status_remessa end,
         data_retorno = case when v_pend=0 then now() else data_retorno end,
         custo = coalesce(p_custo, custo),
         observacoes = coalesce(nullif(btrim(p_observacoes),''), observacoes)
   where id = p_remessa_id returning * into v_rem;
  return v_rem;
end $$;
CREATE FUNCTION public.almox_registrar_emprestimo(p_funcionario_id bigint, p_itens jsonb, p_previsao_devolucao date DEFAULT NULL::date, p_motivo text DEFAULT NULL::text, p_observacoes text DEFAULT NULL::text, p_unidade_id bigint DEFAULT NULL::bigint) RETURNS public.almox_emprestimos
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare v_emp almox_emprestimos%rowtype; it jsonb; v_cod text; v_uni text;
        v_uni_id bigint; v_valor numeric; v_padrao numeric; v_var bigint;
begin
  if jsonb_array_length(coalesce(p_itens,'[]'::jsonb)) = 0 then
    raise exception 'Inclua ao menos um item no emprestimo.';
  end if;
  select unidade_id into v_uni_id from almox_funcionarios where id = p_funcionario_id;
  if v_uni_id is null then raise exception 'Funcionario nao encontrado.'; end if;
  if p_unidade_id is not null and p_unidade_id <> v_uni_id then
    raise exception 'O funcionario e de outra unidade.';
  end if;
  if not almox_opera_unidade(v_uni_id) then raise exception 'Sem permissao nesta unidade.'; end if;
  select codigo into v_uni from almox_unidades where id = v_uni_id;
  select valor_num into v_padrao from almox_parametros
   where unidade_id = v_uni_id and chave = 'custo_extravio_uniforme';
  v_cod := almox_gerar_codigo('EMP', coalesce(v_uni,'GER'));
  insert into almox_emprestimos
    (codigo, unidade_id, funcionario_id, previsao_devolucao, motivo, observacoes, usuario_id)
  values (v_cod, v_uni_id, p_funcionario_id, p_previsao_devolucao, p_motivo, p_observacoes, auth.uid())
  returning * into v_emp;
  for it in select * from jsonb_array_elements(p_itens) loop
    v_var := (it->>'variacao_id')::bigint;
    -- valor de reposicao = o que a empresa pagou na peca.
    -- So cai no valor padrao quando a peca ainda nao tem custo cadastrado.
    select nullif(i.custo_referencia, 0) into v_valor
      from almox_variacoes v join almox_itens i on i.id = v.item_id
     where v.id = v_var;
    v_valor := coalesce(v_valor, v_padrao, 0);
    insert into almox_emprestimo_itens (emprestimo_id, variacao_id, quantidade, valor_unitario_reposicao)
    values (v_emp.id, v_var, (it->>'quantidade')::int, v_valor);
    insert into almox_movimentacoes
      (unidade_id, variacao_id, tipo, quantidade, funcionario_id, emprestimo_id,
       documento, justificativa, usuario_id)
    values (v_uni_id, v_var, 'SAIDA_EMPRESTIMO', (it->>'quantidade')::int,
            p_funcionario_id, v_emp.id, v_cod, coalesce(p_motivo,'Emprestimo ' || v_cod), auth.uid());
  end loop;
  return v_emp;
end $$;
CREATE FUNCTION public.almox_saida_funcionario(p_funcionario_id bigint, p_itens jsonb, p_justificativa text, p_observacoes text DEFAULT NULL::text, p_unidade_id bigint DEFAULT NULL::bigint) RETURNS text
    LANGUAGE plpgsql
    AS $$
declare it jsonb; v_cod text; v_uni text;
begin
  if coalesce(btrim(p_justificativa),'') = '' then
    raise exception 'A justificativa e obrigatoria na saida para funcionario.';
  end if;
  if jsonb_array_length(coalesce(p_itens,'[]'::jsonb)) = 0 then
    raise exception 'Inclua ao menos um item.';
  end if;
  select codigo into v_uni from almox_unidades where id = p_unidade_id;
  v_cod := almox_gerar_codigo('ENT', coalesce(v_uni,'VIX'));
  for it in select * from jsonb_array_elements(p_itens) loop
    insert into almox_movimentacoes
      (unidade_id, variacao_id, tipo, quantidade, funcionario_id,
       documento, justificativa, observacoes, usuario_id)
    values
      (p_unidade_id, (it->>'variacao_id')::bigint, 'SAIDA_FUNCIONARIO',
       (it->>'quantidade')::int, p_funcionario_id, v_cod,
       p_justificativa, p_observacoes, auth.uid());
  end loop;
  return v_cod;
end $$;
CREATE FUNCTION public.almox_sincronizar_variacoes(p_item_id bigint) RETURNS integer
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare v_n int; v_uni bigint;
begin
  select unidade_id into v_uni from almox_itens where id = p_item_id;
  if not almox_gestor_unidade(v_uni) then raise exception 'Sem permissao nesta unidade.'; end if;
  insert into almox_variacoes (unidade_id, item_id, tamanho_id)
  select v_uni, i.id, t.id from almox_itens i
    join almox_tamanhos t on t.grade_id = i.grade_id and t.ativo
   where i.id = p_item_id
  on conflict do nothing;
  get diagnostics v_n = row_count;
  return v_n;
end $$;
CREATE FUNCTION public.almox_ve_unidade(p_unidade_id bigint) RETURNS boolean
    LANGUAGE sql STABLE
    AS $$ select p_unidade_id is not null and almox_papel_unidade(p_unidade_id) <> 'NENHUM' $$;
CREATE TABLE public.almox_acessos (
    id bigint NOT NULL,
    usuario_id uuid NOT NULL,
    unidade_id bigint NOT NULL,
    papel public.almox_papel DEFAULT 'LEITURA'::public.almox_papel NOT NULL,
    ativo boolean DEFAULT true NOT NULL,
    criado_em timestamp with time zone DEFAULT now() NOT NULL
);
CREATE SEQUENCE public.almox_acessos_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
ALTER SEQUENCE public.almox_acessos_id_seq OWNED BY public.almox_acessos.id;
CREATE TABLE public.almox_categorias (
    id bigint NOT NULL,
    nome text NOT NULL,
    cor text DEFAULT '#0B4F53'::text,
    ordem integer DEFAULT 0 NOT NULL,
    ativo boolean DEFAULT true NOT NULL,
    unidade_id bigint NOT NULL
);
CREATE SEQUENCE public.almox_categorias_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
ALTER SEQUENCE public.almox_categorias_id_seq OWNED BY public.almox_categorias.id;
CREATE SEQUENCE public.almox_cobrancas_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
ALTER SEQUENCE public.almox_cobrancas_id_seq OWNED BY public.almox_cobrancas.id;
CREATE TABLE public.almox_contadores (
    chave text NOT NULL,
    valor integer DEFAULT 0 NOT NULL
);
CREATE TABLE public.almox_dotacoes (
    id bigint NOT NULL,
    grupo text NOT NULL,
    cargo text,
    setor text,
    quantidade_minima integer NOT NULL,
    observacoes text,
    ativo boolean DEFAULT true NOT NULL,
    criado_em timestamp with time zone DEFAULT now() NOT NULL,
    unidade_id bigint NOT NULL,
    CONSTRAINT almox_dotacoes_quantidade_minima_check CHECK ((quantidade_minima > 0))
);
CREATE SEQUENCE public.almox_dotacoes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
ALTER SEQUENCE public.almox_dotacoes_id_seq OWNED BY public.almox_dotacoes.id;
CREATE TABLE public.almox_emprestimo_itens (
    id bigint NOT NULL,
    emprestimo_id bigint NOT NULL,
    variacao_id bigint NOT NULL,
    quantidade integer NOT NULL,
    quantidade_devolvida integer DEFAULT 0 NOT NULL,
    observacoes text,
    valor_unitario_reposicao numeric(12,2),
    CONSTRAINT almox_emprestimo_itens_quantidade_check CHECK ((quantidade > 0))
);
CREATE SEQUENCE public.almox_emprestimo_itens_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
ALTER SEQUENCE public.almox_emprestimo_itens_id_seq OWNED BY public.almox_emprestimo_itens.id;
CREATE SEQUENCE public.almox_emprestimos_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
ALTER SEQUENCE public.almox_emprestimos_id_seq OWNED BY public.almox_emprestimos.id;
CREATE TABLE public.almox_fornecedores (
    id bigint NOT NULL,
    nome text NOT NULL,
    cnpj text,
    contato text,
    telefone text,
    email text,
    ativo boolean DEFAULT true NOT NULL,
    criado_em timestamp with time zone DEFAULT now() NOT NULL,
    unidade_id bigint NOT NULL
);
CREATE SEQUENCE public.almox_fornecedores_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
ALTER SEQUENCE public.almox_fornecedores_id_seq OWNED BY public.almox_fornecedores.id;
CREATE SEQUENCE public.almox_funcionarios_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
ALTER SEQUENCE public.almox_funcionarios_id_seq OWNED BY public.almox_funcionarios.id;
CREATE TABLE public.almox_funcoes (
    id bigint NOT NULL,
    unidade_id bigint NOT NULL,
    nome text NOT NULL,
    setor text NOT NULL,
    lideranca boolean DEFAULT false NOT NULL,
    ativo boolean DEFAULT true NOT NULL,
    criado_em timestamp with time zone DEFAULT now() NOT NULL
);
CREATE SEQUENCE public.almox_funcoes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
ALTER SEQUENCE public.almox_funcoes_id_seq OWNED BY public.almox_funcoes.id;
CREATE TABLE public.almox_grades (
    id bigint NOT NULL,
    nome text NOT NULL,
    descricao text,
    ativo boolean DEFAULT true NOT NULL,
    unidade_id bigint NOT NULL
);
CREATE SEQUENCE public.almox_grades_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
ALTER SEQUENCE public.almox_grades_id_seq OWNED BY public.almox_grades.id;
CREATE TABLE public.almox_inventario_itens (
    id bigint NOT NULL,
    inventario_id bigint NOT NULL,
    variacao_id bigint NOT NULL,
    saldo_sistema integer DEFAULT 0 NOT NULL,
    saldo_contado integer,
    observacoes text
);
CREATE SEQUENCE public.almox_inventario_itens_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
ALTER SEQUENCE public.almox_inventario_itens_id_seq OWNED BY public.almox_inventario_itens.id;
CREATE SEQUENCE public.almox_inventarios_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
ALTER SEQUENCE public.almox_inventarios_id_seq OWNED BY public.almox_inventarios.id;
CREATE TABLE public.almox_itens (
    id bigint NOT NULL,
    codigo text,
    nome text NOT NULL,
    categoria_id bigint,
    grade_id bigint NOT NULL,
    cor text,
    descricao text,
    unidade_medida text DEFAULT 'UN'::text NOT NULL,
    epi boolean DEFAULT false NOT NULL,
    ca_epi text,
    exige_devolucao boolean DEFAULT false NOT NULL,
    vida_util_meses integer,
    custo_referencia numeric(12,2) DEFAULT 0,
    estoque_minimo integer DEFAULT 0 NOT NULL,
    ativo boolean DEFAULT true NOT NULL,
    criado_em timestamp with time zone DEFAULT now() NOT NULL,
    atualizado_em timestamp with time zone DEFAULT now() NOT NULL,
    grupo_dotacao text,
    foto_url text,
    unidade_id bigint NOT NULL,
    setores_uso text[] DEFAULT '{}'::text[] NOT NULL,
    observacao_uso text,
    ca_validade date
);
CREATE SEQUENCE public.almox_itens_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
ALTER SEQUENCE public.almox_itens_id_seq OWNED BY public.almox_itens.id;
CREATE TABLE public.almox_movimentacoes (
    id bigint NOT NULL,
    unidade_id bigint,
    variacao_id bigint NOT NULL,
    tipo public.almox_tipo_mov NOT NULL,
    quantidade integer NOT NULL,
    custo_unitario numeric(12,2),
    valor_total numeric(14,2) GENERATED ALWAYS AS (((quantidade)::numeric * COALESCE(custo_unitario, (0)::numeric))) STORED,
    data timestamp with time zone DEFAULT now() NOT NULL,
    funcionario_id bigint,
    fornecedor_id bigint,
    emprestimo_id bigint,
    inventario_id bigint,
    documento text,
    justificativa text,
    observacoes text,
    saldo_anterior integer,
    saldo_posterior integer,
    cancelada boolean DEFAULT false NOT NULL,
    motivo_cancelamento text,
    cancelada_em timestamp with time zone,
    usuario_id uuid,
    criado_em timestamp with time zone DEFAULT now() NOT NULL,
    bucket public.almox_bucket DEFAULT 'DISPONIVEL'::public.almox_bucket NOT NULL,
    remessa_id bigint,
    CONSTRAINT almox_movimentacoes_quantidade_check CHECK ((quantidade > 0)),
    CONSTRAINT ck_almox_mov_regras CHECK (
CASE
    WHEN (tipo = 'SAIDA_FUNCIONARIO'::public.almox_tipo_mov) THEN ((funcionario_id IS NOT NULL) AND (COALESCE(btrim(justificativa), ''::text) <> ''::text))
    WHEN (tipo = 'SAIDA_EMPRESTIMO'::public.almox_tipo_mov) THEN (funcionario_id IS NOT NULL)
    WHEN (tipo = ANY (ARRAY['ENTRADA_AJUSTE'::public.almox_tipo_mov, 'SAIDA_AJUSTE'::public.almox_tipo_mov, 'SAIDA_DESCARTE'::public.almox_tipo_mov, 'ENTRADA_DEVOLUCAO'::public.almox_tipo_mov, 'DESCARTE_LAVANDERIA'::public.almox_tipo_mov])) THEN (COALESCE(btrim(justificativa), ''::text) <> ''::text)
    ELSE true
END)
);
CREATE SEQUENCE public.almox_movimentacoes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
ALTER SEQUENCE public.almox_movimentacoes_id_seq OWNED BY public.almox_movimentacoes.id;
CREATE TABLE public.almox_parametros (
    chave text NOT NULL,
    valor_num numeric(12,2),
    valor_txt text,
    descricao text,
    atualizado_em timestamp with time zone DEFAULT now() NOT NULL,
    unidade_id bigint NOT NULL
);
CREATE TABLE public.almox_remessa_itens (
    id bigint NOT NULL,
    remessa_id bigint NOT NULL,
    variacao_id bigint NOT NULL,
    quantidade integer NOT NULL,
    quantidade_retornada integer DEFAULT 0 NOT NULL,
    quantidade_condenada integer DEFAULT 0 NOT NULL,
    observacoes text,
    CONSTRAINT almox_remessa_itens_quantidade_check CHECK ((quantidade > 0))
);
CREATE SEQUENCE public.almox_remessa_itens_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
ALTER SEQUENCE public.almox_remessa_itens_id_seq OWNED BY public.almox_remessa_itens.id;
CREATE SEQUENCE public.almox_remessas_lavanderia_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
ALTER SEQUENCE public.almox_remessas_lavanderia_id_seq OWNED BY public.almox_remessas_lavanderia.id;
CREATE TABLE public.almox_setores (
    id bigint NOT NULL,
    unidade_id bigint NOT NULL,
    nome text NOT NULL,
    ordem integer DEFAULT 0 NOT NULL,
    ativo boolean DEFAULT true NOT NULL,
    criado_em timestamp with time zone DEFAULT now() NOT NULL
);
CREATE SEQUENCE public.almox_setores_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
ALTER SEQUENCE public.almox_setores_id_seq OWNED BY public.almox_setores.id;
CREATE TABLE public.almox_tamanhos (
    id bigint NOT NULL,
    grade_id bigint NOT NULL,
    rotulo text NOT NULL,
    ordem integer DEFAULT 0 NOT NULL,
    ativo boolean DEFAULT true NOT NULL,
    unidade_id bigint NOT NULL
);
CREATE SEQUENCE public.almox_tamanhos_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
ALTER SEQUENCE public.almox_tamanhos_id_seq OWNED BY public.almox_tamanhos.id;
CREATE TABLE public.almox_treinamentos_epi (
    id bigint NOT NULL,
    unidade_id bigint NOT NULL,
    funcionario_id bigint NOT NULL,
    data date DEFAULT CURRENT_DATE NOT NULL,
    tipo text DEFAULT 'INICIAL'::text NOT NULL,
    responsavel text,
    carga_horaria numeric(5,2),
    conteudo text,
    observacoes text,
    usuario_id uuid,
    criado_em timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT ck_almox_trein_tipo CHECK ((tipo = ANY (ARRAY['INICIAL'::text, 'RECICLAGEM'::text, 'MUDANCA_FUNCAO'::text])))
);
CREATE SEQUENCE public.almox_treinamentos_epi_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
ALTER SEQUENCE public.almox_treinamentos_epi_id_seq OWNED BY public.almox_treinamentos_epi.id;
CREATE SEQUENCE public.almox_unidades_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
ALTER SEQUENCE public.almox_unidades_id_seq OWNED BY public.almox_unidades.id;
CREATE TABLE public.almox_variacoes (
    id bigint NOT NULL,
    item_id bigint NOT NULL,
    tamanho_id bigint,
    sku text,
    saldo integer DEFAULT 0 NOT NULL,
    estoque_minimo integer,
    ativo boolean DEFAULT true NOT NULL,
    atualizado_em timestamp with time zone DEFAULT now() NOT NULL,
    saldo_lavanderia integer DEFAULT 0 NOT NULL,
    unidade_id bigint NOT NULL
);
CREATE SEQUENCE public.almox_variacoes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
ALTER SEQUENCE public.almox_variacoes_id_seq OWNED BY public.almox_variacoes.id;
CREATE VIEW public.almox_vw_cobrancas WITH (security_invoker='on') AS
 SELECT cb.id,
    cb.codigo,
    cb.status,
    cb.quantidade,
    cb.valor_unitario,
    cb.valor_total,
    cb.motivo,
    cb.data,
    cb.baixado_em,
    cb.observacoes,
    cb.unidade_id,
    f.id AS funcionario_id,
    f.nome AS funcionario,
    f.matricula,
    f.cargo,
    f.setor,
    f.ativo AS funcionario_ativo,
    e.codigo AS emprestimo,
    i.nome AS item,
    COALESCE(t.rotulo, 'UNICO'::text) AS tamanho
   FROM (((((public.almox_cobrancas cb
     JOIN public.almox_funcionarios f ON ((f.id = cb.funcionario_id)))
     LEFT JOIN public.almox_emprestimos e ON ((e.id = cb.emprestimo_id)))
     LEFT JOIN public.almox_variacoes v ON ((v.id = cb.variacao_id)))
     LEFT JOIN public.almox_itens i ON ((i.id = v.item_id)))
     LEFT JOIN public.almox_tamanhos t ON ((t.id = v.tamanho_id)));
CREATE VIEW public.almox_vw_posse WITH (security_invoker='on') AS
 SELECT f.id AS funcionario_id,
    f.nome AS funcionario,
    f.setor,
    f.matricula,
    f.unidade_id,
    v.id AS variacao_id,
    i.nome AS item,
    COALESCE(t.rotulo, 'UNICO'::text) AS tamanho,
    v.sku,
    (sum(
        CASE
            WHEN (m.tipo = 'SAIDA_FUNCIONARIO'::public.almox_tipo_mov) THEN m.quantidade
            WHEN (m.tipo = 'ENTRADA_DEVOLUCAO'::public.almox_tipo_mov) THEN (- m.quantidade)
            ELSE 0
        END))::integer AS quantidade,
    max(m.data) FILTER (WHERE (m.tipo = 'SAIDA_FUNCIONARIO'::public.almox_tipo_mov)) AS ultima_entrega
   FROM ((((public.almox_movimentacoes m
     JOIN public.almox_funcionarios f ON ((f.id = m.funcionario_id)))
     JOIN public.almox_variacoes v ON ((v.id = m.variacao_id)))
     JOIN public.almox_itens i ON ((i.id = v.item_id)))
     LEFT JOIN public.almox_tamanhos t ON ((t.id = v.tamanho_id)))
  WHERE ((m.cancelada = false) AND (m.tipo = ANY (ARRAY['SAIDA_FUNCIONARIO'::public.almox_tipo_mov, 'ENTRADA_DEVOLUCAO'::public.almox_tipo_mov])))
  GROUP BY f.id, f.nome, f.setor, f.matricula, f.unidade_id, v.id, i.nome, t.rotulo, v.sku
 HAVING (sum(
        CASE
            WHEN (m.tipo = 'SAIDA_FUNCIONARIO'::public.almox_tipo_mov) THEN m.quantidade
            WHEN (m.tipo = 'ENTRADA_DEVOLUCAO'::public.almox_tipo_mov) THEN (- m.quantidade)
            ELSE 0
        END) > 0);
CREATE VIEW public.almox_vw_dotacao WITH (security_invoker='on') AS
 WITH regra AS (
         SELECT DISTINCT ON (f_1.id, d.grupo) f_1.id AS funcionario_id,
            d.grupo,
            d.quantidade_minima
           FROM (public.almox_funcionarios f_1
             JOIN public.almox_dotacoes d ON ((d.ativo AND ((d.cargo IS NULL) OR (d.cargo = f_1.cargo)) AND ((d.setor IS NULL) OR (d.setor = f_1.setor)))))
          WHERE f_1.ativo
          ORDER BY f_1.id, d.grupo, (((d.cargo IS NOT NULL))::integer + ((d.setor IS NOT NULL))::integer) DESC, (((d.cargo IS NOT NULL))::integer) DESC
        ), posse AS (
         SELECT p_1.funcionario_id,
            i.grupo_dotacao AS grupo,
            (sum(p_1.quantidade))::integer AS qtd
           FROM ((public.almox_vw_posse p_1
             JOIN public.almox_variacoes v ON ((v.id = p_1.variacao_id)))
             JOIN public.almox_itens i ON ((i.id = v.item_id)))
          WHERE (i.grupo_dotacao IS NOT NULL)
          GROUP BY p_1.funcionario_id, i.grupo_dotacao
        ), emprestado AS (
         SELECT e.funcionario_id,
            i.grupo_dotacao AS grupo,
            (sum((ei.quantidade - ei.quantidade_devolvida)))::integer AS qtd
           FROM (((public.almox_emprestimo_itens ei
             JOIN public.almox_emprestimos e ON (((e.id = ei.emprestimo_id) AND (e.status = ANY (ARRAY['ABERTO'::public.almox_status_emprestimo, 'PARCIAL'::public.almox_status_emprestimo])))))
             JOIN public.almox_variacoes v ON ((v.id = ei.variacao_id)))
             JOIN public.almox_itens i ON ((i.id = v.item_id)))
          WHERE (i.grupo_dotacao IS NOT NULL)
          GROUP BY e.funcionario_id, i.grupo_dotacao
        )
 SELECT f.id AS funcionario_id,
    f.nome AS funcionario,
    f.matricula,
    f.cargo,
    f.setor,
    f.unidade_id,
    f.vinculo,
    r.grupo,
    r.quantidade_minima,
    COALESCE(p.qtd, 0) AS em_posse,
    COALESCE(em.qtd, 0) AS emprestado,
    GREATEST((r.quantidade_minima - COALESCE(p.qtd, 0)), 0) AS falta
   FROM (((regra r
     JOIN public.almox_funcionarios f ON ((f.id = r.funcionario_id)))
     LEFT JOIN posse p ON (((p.funcionario_id = r.funcionario_id) AND (p.grupo = r.grupo))))
     LEFT JOIN emprestado em ON (((em.funcionario_id = r.funcionario_id) AND (em.grupo = r.grupo))));
CREATE VIEW public.almox_vw_emprestimos AS
SELECT
    NULL::bigint AS id,
    NULL::text AS codigo,
    NULL::public.almox_status_emprestimo AS status,
    NULL::timestamp with time zone AS data_saida,
    NULL::date AS previsao_devolucao,
    NULL::bigint AS unidade_id,
    NULL::text AS motivo,
    NULL::text AS observacoes,
    NULL::boolean AS recibo_assinado,
    NULL::timestamp with time zone AS assinado_em,
    NULL::bigint AS funcionario_id,
    NULL::text AS funcionario,
    NULL::text AS matricula,
    NULL::text AS cargo,
    NULL::text AS setor,
    NULL::date AS termo_assinado_em,
    NULL::integer AS total_itens,
    NULL::integer AS pendentes,
    NULL::numeric(14,2) AS valor_reposicao,
    NULL::numeric(14,2) AS valor_em_aberto,
    NULL::boolean AS atrasado;
CREATE VIEW public.almox_vw_entregas AS
SELECT
    NULL::text AS codigo,
    NULL::timestamp with time zone AS data,
    NULL::bigint AS unidade_id,
    NULL::bigint AS funcionario_id,
    NULL::text AS funcionario,
    NULL::text AS matricula,
    NULL::text AS cargo,
    NULL::text AS setor,
    NULL::text AS motivo,
    NULL::text AS observacoes,
    NULL::integer AS total_pecas,
    NULL::integer AS linhas,
    NULL::boolean AS tem_cancelamento,
    NULL::text AS entregue_por;
CREATE VIEW public.almox_vw_epi WITH (security_invoker='on') AS
 SELECT id AS item_id,
    unidade_id,
    nome,
    ca_epi,
    ca_validade,
    ativo,
        CASE
            WHEN ((ca_epi IS NULL) OR (btrim(ca_epi) = ''::text)) THEN 'SEM_CA'::text
            WHEN (ca_validade IS NULL) THEN 'SEM_VALIDADE'::text
            WHEN (ca_validade < CURRENT_DATE) THEN 'VENCIDO'::text
            WHEN (ca_validade < (CURRENT_DATE + 60)) THEN 'VENCENDO'::text
            ELSE 'OK'::text
        END AS situacao_ca,
    (ca_validade - CURRENT_DATE) AS dias_para_vencer
   FROM public.almox_itens i
  WHERE epi;
CREATE VIEW public.almox_vw_equipe WITH (security_invoker='on') AS
 SELECT f.id,
    f.nome,
    f.matricula,
    f.cpf,
    f.unidade_id,
    f.setor,
    f.cargo,
    f.funcao_id,
    fu.lideranca AS funcao_lideranca,
    f.lideranca,
    f.vinculo,
    f.ativo,
    f.data_admissao,
    f.data_desligamento,
    f.termo_assinado_em,
    COALESCE(( SELECT (sum(p.quantidade))::integer AS sum
           FROM public.almox_vw_posse p
          WHERE (p.funcionario_id = f.id)), 0) AS pecas_em_posse,
    ( SELECT count(*) AS count
           FROM public.almox_emprestimos e
          WHERE ((e.funcionario_id = f.id) AND (e.status = ANY (ARRAY['ABERTO'::public.almox_status_emprestimo, 'PARCIAL'::public.almox_status_emprestimo])))) AS emprestimos_abertos
   FROM (public.almox_funcionarios f
     LEFT JOIN public.almox_funcoes fu ON ((fu.id = f.funcao_id)));
CREATE VIEW public.almox_vw_estoque WITH (security_invoker='on') AS
 SELECT v.id AS variacao_id,
    v.sku,
    v.saldo,
    v.saldo_lavanderia,
    (v.saldo + v.saldo_lavanderia) AS saldo_total,
    v.ativo AS variacao_ativa,
    v.unidade_id,
    un.codigo AS unidade,
    un.nome AS unidade_nome,
    i.id AS item_id,
    i.nome AS item,
    i.codigo AS item_codigo,
    i.cor,
    i.epi,
    i.exige_devolucao,
    i.custo_referencia,
    i.ativo AS item_ativo,
    i.grupo_dotacao,
    i.foto_url,
    ((((v.saldo + v.saldo_lavanderia))::numeric * COALESCE(i.custo_referencia, (0)::numeric)))::numeric(14,2) AS valor_estoque,
    COALESCE(v.estoque_minimo, i.estoque_minimo, 0) AS estoque_minimo,
    c.id AS categoria_id,
    c.nome AS categoria,
    g.id AS grade_id,
    g.nome AS grade,
    t.id AS tamanho_id,
    COALESCE(t.rotulo, 'UNICO'::text) AS tamanho,
    COALESCE(t.ordem, 0) AS tamanho_ordem,
        CASE
            WHEN (v.saldo <= 0) THEN 'ZERADO'::text
            WHEN (v.saldo <= COALESCE(v.estoque_minimo, i.estoque_minimo, 0)) THEN 'BAIXO'::text
            ELSE 'OK'::text
        END AS situacao
   FROM (((((public.almox_variacoes v
     JOIN public.almox_unidades un ON ((un.id = v.unidade_id)))
     JOIN public.almox_itens i ON ((i.id = v.item_id)))
     LEFT JOIN public.almox_categorias c ON ((c.id = i.categoria_id)))
     JOIN public.almox_grades g ON ((g.id = i.grade_id)))
     LEFT JOIN public.almox_tamanhos t ON ((t.id = v.tamanho_id)));
CREATE VIEW public.almox_vw_pendencias WITH (security_invoker='on') AS
 SELECT f.id AS funcionario_id,
    f.nome AS funcionario,
    f.matricula,
    f.cargo,
    f.setor,
    f.unidade_id,
    f.vinculo,
    f.data_desligamento,
    (CURRENT_DATE - f.data_desligamento) AS dias_desde_desligamento,
    p.variacao_id,
    p.item,
    p.tamanho,
    p.sku,
    p.quantidade,
    p.ultima_entrega,
    (COALESCE(i.custo_referencia, (0)::numeric))::numeric(12,2) AS custo_unitario,
    (((p.quantidade)::numeric * COALESCE(i.custo_referencia, (0)::numeric)))::numeric(14,2) AS valor_estimado,
    i.epi,
    i.exige_devolucao,
    (EXISTS ( SELECT 1
           FROM public.almox_cobrancas cb
          WHERE ((cb.funcionario_id = f.id) AND (cb.variacao_id = p.variacao_id) AND (cb.status = ANY (ARRAY['PENDENTE'::public.almox_status_cobranca, 'DESCONTADA'::public.almox_status_cobranca]))))) AS tem_cobranca
   FROM (((public.almox_vw_posse p
     JOIN public.almox_funcionarios f ON ((f.id = p.funcionario_id)))
     JOIN public.almox_variacoes v ON ((v.id = p.variacao_id)))
     JOIN public.almox_itens i ON ((i.id = v.item_id)))
  WHERE (f.ativo = false);
CREATE VIEW public.almox_vw_indice_devolucao WITH (security_invoker='on') AS
 WITH base AS (
         SELECT f.unidade_id,
            (sum(
                CASE
                    WHEN (m.tipo = 'SAIDA_FUNCIONARIO'::public.almox_tipo_mov) THEN m.quantidade
                    ELSE 0
                END))::integer AS entregues,
            (sum(
                CASE
                    WHEN (m.tipo = 'ENTRADA_DEVOLUCAO'::public.almox_tipo_mov) THEN m.quantidade
                    ELSE 0
                END))::integer AS devolvidas
           FROM (public.almox_movimentacoes m
             JOIN public.almox_funcionarios f ON (((f.id = m.funcionario_id) AND (f.ativo = false))))
          WHERE ((m.cancelada = false) AND (m.tipo = ANY (ARRAY['SAIDA_FUNCIONARIO'::public.almox_tipo_mov, 'ENTRADA_DEVOLUCAO'::public.almox_tipo_mov])))
          GROUP BY f.unidade_id
        ), pend AS (
         SELECT almox_vw_pendencias.unidade_id,
            (count(DISTINCT almox_vw_pendencias.funcionario_id))::integer AS com_pendencia,
            (sum(almox_vw_pendencias.valor_estimado))::numeric(14,2) AS valor
           FROM public.almox_vw_pendencias
          GROUP BY almox_vw_pendencias.unidade_id
        ), desl AS (
         SELECT almox_funcionarios.unidade_id,
            (count(*))::integer AS n
           FROM public.almox_funcionarios
          WHERE (almox_funcionarios.ativo = false)
          GROUP BY almox_funcionarios.unidade_id
        )
 SELECT u.id AS unidade_id,
    u.codigo AS unidade,
    COALESCE(d.n, 0) AS desligados,
    COALESCE(p.com_pendencia, 0) AS desligados_com_pendencia,
    COALESCE(b.entregues, 0) AS pecas_entregues,
    COALESCE(b.devolvidas, 0) AS pecas_devolvidas,
    GREATEST((COALESCE(b.entregues, 0) - COALESCE(b.devolvidas, 0)), 0) AS pecas_nao_devolvidas,
        CASE
            WHEN (COALESCE(b.entregues, 0) > 0) THEN round(((100.0 * (GREATEST((b.entregues - b.devolvidas), 0))::numeric) / (b.entregues)::numeric), 1)
            ELSE (0)::numeric
        END AS indice_nao_devolucao,
    (COALESCE(p.valor, (0)::numeric))::numeric(14,2) AS valor_pendente
   FROM (((public.almox_unidades u
     LEFT JOIN base b ON ((b.unidade_id = u.id)))
     LEFT JOIN pend p ON ((p.unidade_id = u.id)))
     LEFT JOIN desl d ON ((d.unidade_id = u.id)));
CREATE VIEW public.almox_vw_lavanderia WITH (security_invoker='on') AS
 SELECT v.id AS variacao_id,
    v.sku,
    v.unidade_id,
    i.id AS item_id,
    i.nome AS item,
    c.nome AS categoria,
    COALESCE(t.rotulo, 'UNICO'::text) AS tamanho,
    COALESCE(t.ordem, 0) AS tamanho_ordem,
    v.saldo AS disponivel,
    v.saldo_lavanderia AS em_lavanderia,
    (COALESCE(env.enviado, (0)::bigint))::integer AS enviado,
    ((v.saldo_lavanderia - COALESCE(env.enviado, (0)::bigint)))::integer AS aguardando_envio
   FROM ((((public.almox_variacoes v
     JOIN public.almox_itens i ON ((i.id = v.item_id)))
     LEFT JOIN public.almox_categorias c ON ((c.id = i.categoria_id)))
     LEFT JOIN public.almox_tamanhos t ON ((t.id = v.tamanho_id)))
     LEFT JOIN ( SELECT ri.variacao_id,
            sum(((ri.quantidade - ri.quantidade_retornada) - ri.quantidade_condenada)) AS enviado
           FROM (public.almox_remessa_itens ri
             JOIN public.almox_remessas_lavanderia r ON ((r.id = ri.remessa_id)))
          WHERE (r.status = 'ENVIADA'::public.almox_status_remessa)
          GROUP BY ri.variacao_id) env ON ((env.variacao_id = v.id)));
CREATE VIEW public.almox_vw_mov_mensal WITH (security_invoker='on') AS
 SELECT (date_trunc('month'::text, data))::date AS mes,
    unidade_id,
    tipo,
    (sum(quantidade))::integer AS quantidade,
    (sum(valor_total))::numeric(14,2) AS valor
   FROM public.almox_movimentacoes m
  WHERE (cancelada = false)
  GROUP BY ((date_trunc('month'::text, data))::date), unidade_id, tipo;
CREATE VIEW public.almox_vw_movimentacoes WITH (security_invoker='on') AS
 SELECT m.id,
    m.data,
    m.tipo,
    m.bucket,
    m.quantidade,
    m.custo_unitario,
    m.valor_total,
    m.documento,
    m.justificativa,
    m.observacoes,
    m.cancelada,
    m.motivo_cancelamento,
    m.saldo_anterior,
    m.saldo_posterior,
    m.emprestimo_id,
    m.inventario_id,
    m.remessa_id,
    m.unidade_id,
    public.almox_e_entrada(m.tipo) AS e_entrada,
    v.id AS variacao_id,
    v.sku,
    i.nome AS item,
    COALESCE(t.rotulo, 'UNICO'::text) AS tamanho,
    c.nome AS categoria,
    f.id AS funcionario_id,
    f.nome AS funcionario,
    f.setor,
    fo.nome AS fornecedor,
    u.nome AS usuario
   FROM (((((((public.almox_movimentacoes m
     JOIN public.almox_variacoes v ON ((v.id = m.variacao_id)))
     JOIN public.almox_itens i ON ((i.id = v.item_id)))
     LEFT JOIN public.almox_tamanhos t ON ((t.id = v.tamanho_id)))
     LEFT JOIN public.almox_categorias c ON ((c.id = i.categoria_id)))
     LEFT JOIN public.almox_funcionarios f ON ((f.id = m.funcionario_id)))
     LEFT JOIN public.almox_fornecedores fo ON ((fo.id = m.fornecedor_id)))
     LEFT JOIN public.almox_usuarios u ON ((u.id = m.usuario_id)));
CREATE VIEW public.almox_vw_remessas AS
SELECT
    NULL::bigint AS id,
    NULL::text AS codigo,
    NULL::public.almox_status_remessa AS status,
    NULL::timestamp with time zone AS data_envio,
    NULL::timestamp with time zone AS data_retorno,
    NULL::numeric(12,2) AS custo,
    NULL::text AS observacoes,
    NULL::bigint AS unidade_id,
    NULL::text AS responsavel,
    NULL::text AS local,
    NULL::integer AS total_pecas,
    NULL::integer AS retornadas,
    NULL::integer AS condenadas,
    NULL::integer AS pendentes,
    NULL::boolean AS demorada;
CREATE VIEW public.almox_vw_treinamento_pendente WITH (security_invoker='on') AS
 SELECT id AS funcionario_id,
    unidade_id,
    nome,
    setor,
    cargo,
    data_admissao,
    ( SELECT max(t.data) AS max
           FROM public.almox_treinamentos_epi t
          WHERE (t.funcionario_id = f.id)) AS ultimo_treinamento,
    (EXISTS ( SELECT 1
           FROM ((public.almox_movimentacoes m
             JOIN public.almox_variacoes v ON ((v.id = m.variacao_id)))
             JOIN public.almox_itens i ON ((i.id = v.item_id)))
          WHERE ((m.funcionario_id = f.id) AND (m.cancelada = false) AND i.epi AND (m.tipo = ANY (ARRAY['SAIDA_FUNCIONARIO'::public.almox_tipo_mov, 'SAIDA_EMPRESTIMO'::public.almox_tipo_mov]))))) AS ja_recebeu_epi
   FROM public.almox_funcionarios f
  WHERE ativo;
ALTER TABLE ONLY public.almox_acessos ALTER COLUMN id SET DEFAULT nextval('public.almox_acessos_id_seq'::regclass);
ALTER TABLE ONLY public.almox_categorias ALTER COLUMN id SET DEFAULT nextval('public.almox_categorias_id_seq'::regclass);
ALTER TABLE ONLY public.almox_cobrancas ALTER COLUMN id SET DEFAULT nextval('public.almox_cobrancas_id_seq'::regclass);
ALTER TABLE ONLY public.almox_dotacoes ALTER COLUMN id SET DEFAULT nextval('public.almox_dotacoes_id_seq'::regclass);
ALTER TABLE ONLY public.almox_emprestimo_itens ALTER COLUMN id SET DEFAULT nextval('public.almox_emprestimo_itens_id_seq'::regclass);
ALTER TABLE ONLY public.almox_emprestimos ALTER COLUMN id SET DEFAULT nextval('public.almox_emprestimos_id_seq'::regclass);
ALTER TABLE ONLY public.almox_fornecedores ALTER COLUMN id SET DEFAULT nextval('public.almox_fornecedores_id_seq'::regclass);
ALTER TABLE ONLY public.almox_funcionarios ALTER COLUMN id SET DEFAULT nextval('public.almox_funcionarios_id_seq'::regclass);
ALTER TABLE ONLY public.almox_funcoes ALTER COLUMN id SET DEFAULT nextval('public.almox_funcoes_id_seq'::regclass);
ALTER TABLE ONLY public.almox_grades ALTER COLUMN id SET DEFAULT nextval('public.almox_grades_id_seq'::regclass);
ALTER TABLE ONLY public.almox_inventario_itens ALTER COLUMN id SET DEFAULT nextval('public.almox_inventario_itens_id_seq'::regclass);
ALTER TABLE ONLY public.almox_inventarios ALTER COLUMN id SET DEFAULT nextval('public.almox_inventarios_id_seq'::regclass);
ALTER TABLE ONLY public.almox_itens ALTER COLUMN id SET DEFAULT nextval('public.almox_itens_id_seq'::regclass);
ALTER TABLE ONLY public.almox_movimentacoes ALTER COLUMN id SET DEFAULT nextval('public.almox_movimentacoes_id_seq'::regclass);
ALTER TABLE ONLY public.almox_remessa_itens ALTER COLUMN id SET DEFAULT nextval('public.almox_remessa_itens_id_seq'::regclass);
ALTER TABLE ONLY public.almox_remessas_lavanderia ALTER COLUMN id SET DEFAULT nextval('public.almox_remessas_lavanderia_id_seq'::regclass);
ALTER TABLE ONLY public.almox_setores ALTER COLUMN id SET DEFAULT nextval('public.almox_setores_id_seq'::regclass);
ALTER TABLE ONLY public.almox_tamanhos ALTER COLUMN id SET DEFAULT nextval('public.almox_tamanhos_id_seq'::regclass);
ALTER TABLE ONLY public.almox_treinamentos_epi ALTER COLUMN id SET DEFAULT nextval('public.almox_treinamentos_epi_id_seq'::regclass);
ALTER TABLE ONLY public.almox_unidades ALTER COLUMN id SET DEFAULT nextval('public.almox_unidades_id_seq'::regclass);
ALTER TABLE ONLY public.almox_variacoes ALTER COLUMN id SET DEFAULT nextval('public.almox_variacoes_id_seq'::regclass);
