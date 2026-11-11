SET check_function_bodies = false;

ALTER TABLE ONLY public.almox_acessos
    ADD CONSTRAINT almox_acessos_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.almox_acessos
    ADD CONSTRAINT almox_acessos_usuario_id_unidade_id_key UNIQUE (usuario_id, unidade_id);
ALTER TABLE ONLY public.almox_categorias
    ADD CONSTRAINT almox_categorias_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.almox_cobrancas
    ADD CONSTRAINT almox_cobrancas_codigo_key UNIQUE (codigo);
ALTER TABLE ONLY public.almox_cobrancas
    ADD CONSTRAINT almox_cobrancas_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.almox_contadores
    ADD CONSTRAINT almox_contadores_pkey PRIMARY KEY (chave);
ALTER TABLE ONLY public.almox_dotacoes
    ADD CONSTRAINT almox_dotacoes_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.almox_emprestimo_itens
    ADD CONSTRAINT almox_emprestimo_itens_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.almox_emprestimos
    ADD CONSTRAINT almox_emprestimos_codigo_key UNIQUE (codigo);
ALTER TABLE ONLY public.almox_emprestimos
    ADD CONSTRAINT almox_emprestimos_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.almox_fornecedores
    ADD CONSTRAINT almox_fornecedores_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.almox_funcionarios
    ADD CONSTRAINT almox_funcionarios_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.almox_funcoes
    ADD CONSTRAINT almox_funcoes_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.almox_grades
    ADD CONSTRAINT almox_grades_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.almox_inventario_itens
    ADD CONSTRAINT almox_inventario_itens_inventario_id_variacao_id_key UNIQUE (inventario_id, variacao_id);
ALTER TABLE ONLY public.almox_inventario_itens
    ADD CONSTRAINT almox_inventario_itens_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.almox_inventarios
    ADD CONSTRAINT almox_inventarios_codigo_key UNIQUE (codigo);
ALTER TABLE ONLY public.almox_inventarios
    ADD CONSTRAINT almox_inventarios_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.almox_itens
    ADD CONSTRAINT almox_itens_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.almox_movimentacoes
    ADD CONSTRAINT almox_movimentacoes_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.almox_remessa_itens
    ADD CONSTRAINT almox_remessa_itens_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.almox_remessas_lavanderia
    ADD CONSTRAINT almox_remessas_lavanderia_codigo_key UNIQUE (codigo);
ALTER TABLE ONLY public.almox_remessas_lavanderia
    ADD CONSTRAINT almox_remessas_lavanderia_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.almox_setores
    ADD CONSTRAINT almox_setores_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.almox_tamanhos
    ADD CONSTRAINT almox_tamanhos_grade_id_rotulo_key UNIQUE (grade_id, rotulo);
ALTER TABLE ONLY public.almox_tamanhos
    ADD CONSTRAINT almox_tamanhos_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.almox_treinamentos_epi
    ADD CONSTRAINT almox_treinamentos_epi_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.almox_unidades
    ADD CONSTRAINT almox_unidades_codigo_key UNIQUE (codigo);
ALTER TABLE ONLY public.almox_unidades
    ADD CONSTRAINT almox_unidades_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.almox_usuarios
    ADD CONSTRAINT almox_usuarios_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.almox_variacoes
    ADD CONSTRAINT almox_variacoes_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.almox_variacoes
    ADD CONSTRAINT almox_variacoes_sku_key UNIQUE (sku);
CREATE INDEX idx_almox_acessos_uni ON public.almox_acessos USING btree (unidade_id);
CREATE INDEX idx_almox_acessos_user ON public.almox_acessos USING btree (usuario_id);
CREATE INDEX idx_almox_cat_uni ON public.almox_categorias USING btree (unidade_id);
CREATE INDEX idx_almox_cob_func ON public.almox_cobrancas USING btree (funcionario_id);
CREATE INDEX idx_almox_cob_status ON public.almox_cobrancas USING btree (status);
CREATE INDEX idx_almox_cob_var ON public.almox_cobrancas USING btree (variacao_id, funcionario_id);
CREATE INDEX idx_almox_emp_func ON public.almox_emprestimos USING btree (funcionario_id);
CREATE INDEX idx_almox_emp_status ON public.almox_emprestimos USING btree (status);
CREATE INDEX idx_almox_empit_emp ON public.almox_emprestimo_itens USING btree (emprestimo_id);
CREATE INDEX idx_almox_empit_var ON public.almox_emprestimo_itens USING btree (variacao_id);
CREATE INDEX idx_almox_forn_uni ON public.almox_fornecedores USING btree (unidade_id);
CREATE INDEX idx_almox_func_ativo ON public.almox_funcionarios USING btree (ativo);
CREATE INDEX idx_almox_func_funcao ON public.almox_funcionarios USING btree (funcao_id);
CREATE INDEX idx_almox_func_nome ON public.almox_funcionarios USING btree (lower(nome));
CREATE INDEX idx_almox_func_unidade ON public.almox_funcionarios USING btree (unidade_id);
CREATE INDEX idx_almox_func_vinculo ON public.almox_funcionarios USING btree (vinculo);
CREATE INDEX idx_almox_funcao_uni ON public.almox_funcoes USING btree (unidade_id);
CREATE INDEX idx_almox_grade_uni ON public.almox_grades USING btree (unidade_id);
CREATE INDEX idx_almox_item_uni ON public.almox_itens USING btree (unidade_id);
CREATE INDEX idx_almox_itens_cat ON public.almox_itens USING btree (categoria_id);
CREATE INDEX idx_almox_itens_grupo ON public.almox_itens USING btree (grupo_dotacao);
CREATE INDEX idx_almox_mov_bucket ON public.almox_movimentacoes USING btree (bucket);
CREATE INDEX idx_almox_mov_data ON public.almox_movimentacoes USING btree (data DESC);
CREATE INDEX idx_almox_mov_doc ON public.almox_movimentacoes USING btree (documento);
CREATE INDEX idx_almox_mov_func ON public.almox_movimentacoes USING btree (funcionario_id);
CREATE INDEX idx_almox_mov_func_tipo ON public.almox_movimentacoes USING btree (funcionario_id, tipo) WHERE (cancelada = false);
CREATE INDEX idx_almox_mov_tipo ON public.almox_movimentacoes USING btree (tipo);
CREATE INDEX idx_almox_mov_var ON public.almox_movimentacoes USING btree (variacao_id);
CREATE INDEX idx_almox_remit_rem ON public.almox_remessa_itens USING btree (remessa_id);
CREATE INDEX idx_almox_remit_var ON public.almox_remessa_itens USING btree (variacao_id);
CREATE INDEX idx_almox_setor_uni ON public.almox_setores USING btree (unidade_id);
CREATE INDEX idx_almox_trein_func ON public.almox_treinamentos_epi USING btree (funcionario_id);
CREATE INDEX idx_almox_trein_uni ON public.almox_treinamentos_epi USING btree (unidade_id);
CREATE INDEX idx_almox_var_item ON public.almox_variacoes USING btree (item_id);
CREATE INDEX idx_almox_var_unidade ON public.almox_variacoes USING btree (unidade_id);
CREATE UNIQUE INDEX uq_almox_cat_uni ON public.almox_categorias USING btree (unidade_id, nome);
CREATE UNIQUE INDEX uq_almox_dotacao ON public.almox_dotacoes USING btree (unidade_id, grupo, COALESCE(cargo, ''::text), COALESCE(setor, ''::text));
CREATE UNIQUE INDEX uq_almox_func_matr ON public.almox_funcionarios USING btree (unidade_id, matricula) WHERE (matricula IS NOT NULL);
CREATE UNIQUE INDEX uq_almox_funcao ON public.almox_funcoes USING btree (unidade_id, nome, setor);
CREATE UNIQUE INDEX uq_almox_grade_uni ON public.almox_grades USING btree (unidade_id, nome);
CREATE UNIQUE INDEX uq_almox_item_uni ON public.almox_itens USING btree (unidade_id, codigo) WHERE (codigo IS NOT NULL);
CREATE UNIQUE INDEX uq_almox_param ON public.almox_parametros USING btree (unidade_id, chave);
CREATE UNIQUE INDEX uq_almox_setor ON public.almox_setores USING btree (unidade_id, nome);
CREATE UNIQUE INDEX uq_almox_var_uni_item_tam ON public.almox_variacoes USING btree (unidade_id, item_id, COALESCE(tamanho_id, ('-1'::integer)::bigint));
CREATE OR REPLACE VIEW public.almox_vw_emprestimos WITH (security_invoker='on') AS
 SELECT e.id,
    e.codigo,
    e.status,
    e.data_saida,
    e.previsao_devolucao,
    e.unidade_id,
    e.motivo,
    e.observacoes,
    e.recibo_assinado,
    e.assinado_em,
    f.id AS funcionario_id,
    f.nome AS funcionario,
    f.matricula,
    f.cargo,
    f.setor,
    f.termo_assinado_em,
    (COALESCE(sum(ei.quantidade), (0)::bigint))::integer AS total_itens,
    (COALESCE(sum((ei.quantidade - ei.quantidade_devolvida)), (0)::bigint))::integer AS pendentes,
    (COALESCE(sum(((ei.quantidade)::numeric * ei.valor_unitario_reposicao)), (0)::numeric))::numeric(14,2) AS valor_reposicao,
    (COALESCE(sum((((ei.quantidade - ei.quantidade_devolvida))::numeric * ei.valor_unitario_reposicao)), (0)::numeric))::numeric(14,2) AS valor_em_aberto,
    ((e.status = ANY (ARRAY['ABERTO'::public.almox_status_emprestimo, 'PARCIAL'::public.almox_status_emprestimo])) AND (e.previsao_devolucao IS NOT NULL) AND (e.previsao_devolucao < CURRENT_DATE)) AS atrasado
   FROM ((public.almox_emprestimos e
     JOIN public.almox_funcionarios f ON ((f.id = e.funcionario_id)))
     LEFT JOIN public.almox_emprestimo_itens ei ON ((ei.emprestimo_id = e.id)))
  GROUP BY e.id, f.id;
CREATE OR REPLACE VIEW public.almox_vw_entregas WITH (security_invoker='on') AS
 SELECT m.documento AS codigo,
    min(m.data) AS data,
    m.unidade_id,
    f.id AS funcionario_id,
    f.nome AS funcionario,
    f.matricula,
    f.cargo,
    f.setor,
    min(m.justificativa) AS motivo,
    min(m.observacoes) AS observacoes,
    (sum(m.quantidade))::integer AS total_pecas,
    (count(*))::integer AS linhas,
    bool_or(m.cancelada) AS tem_cancelamento,
    min(u.nome) AS entregue_por
   FROM ((public.almox_movimentacoes m
     JOIN public.almox_funcionarios f ON ((f.id = m.funcionario_id)))
     LEFT JOIN public.almox_usuarios u ON ((u.id = m.usuario_id)))
  WHERE ((m.tipo = 'SAIDA_FUNCIONARIO'::public.almox_tipo_mov) AND (m.documento ~~ 'ENT-%'::text))
  GROUP BY m.documento, m.unidade_id, f.id;
CREATE OR REPLACE VIEW public.almox_vw_remessas WITH (security_invoker='on') AS
 SELECT r.id,
    r.codigo,
    r.status,
    r.data_envio,
    r.data_retorno,
    r.custo,
    r.observacoes,
    r.unidade_id,
    COALESCE(r.responsavel, f.nome) AS responsavel,
    COALESCE(r.local, 'Lavanderia interna'::text) AS local,
    (COALESCE(sum(ri.quantidade), (0)::bigint))::integer AS total_pecas,
    (COALESCE(sum(ri.quantidade_retornada), (0)::bigint))::integer AS retornadas,
    (COALESCE(sum(ri.quantidade_condenada), (0)::bigint))::integer AS condenadas,
    (COALESCE(sum(((ri.quantidade - ri.quantidade_retornada) - ri.quantidade_condenada)), (0)::bigint))::integer AS pendentes,
    ((r.status = 'ENVIADA'::public.almox_status_remessa) AND (r.data_envio < (now() - '4 days'::interval))) AS demorada
   FROM ((public.almox_remessas_lavanderia r
     LEFT JOIN public.almox_fornecedores f ON ((f.id = r.fornecedor_id)))
     LEFT JOIN public.almox_remessa_itens ri ON ((ri.remessa_id = r.id)))
  GROUP BY r.id, f.nome;
CREATE TRIGGER almox_trg_cob_func BEFORE INSERT OR UPDATE ON public.almox_cobrancas FOR EACH ROW EXECUTE FUNCTION public.almox_fn_valida_unidade_funcionario();
CREATE TRIGGER almox_trg_emp_func BEFORE INSERT OR UPDATE ON public.almox_emprestimos FOR EACH ROW EXECUTE FUNCTION public.almox_fn_valida_unidade_funcionario();
CREATE TRIGGER almox_trg_empit_uni BEFORE INSERT OR UPDATE ON public.almox_emprestimo_itens FOR EACH ROW EXECUTE FUNCTION public.almox_fn_valida_item_emprestimo();
CREATE TRIGGER almox_trg_guarda_usuario BEFORE UPDATE ON public.almox_usuarios FOR EACH ROW EXECUTE FUNCTION public.almox_fn_guarda_usuario();
CREATE TRIGGER almox_trg_mov BEFORE INSERT ON public.almox_movimentacoes FOR EACH ROW EXECUTE FUNCTION public.almox_fn_aplicar_mov();
CREATE TRIGGER almox_trg_propaga_funcao AFTER UPDATE ON public.almox_funcoes FOR EACH ROW EXECUTE FUNCTION public.almox_fn_propaga_funcao();
CREATE TRIGGER almox_trg_setor_func BEFORE INSERT OR UPDATE ON public.almox_funcionarios FOR EACH ROW EXECUTE FUNCTION public.almox_fn_valida_setor();
CREATE TRIGGER almox_trg_setor_funcao BEFORE INSERT OR UPDATE ON public.almox_funcoes FOR EACH ROW EXECUTE FUNCTION public.almox_fn_valida_setor();
CREATE TRIGGER almox_trg_sku BEFORE INSERT ON public.almox_variacoes FOR EACH ROW EXECUTE FUNCTION public.almox_fn_sku();
CREATE TRIGGER almox_trg_sync_funcao BEFORE INSERT OR UPDATE ON public.almox_funcionarios FOR EACH ROW EXECUTE FUNCTION public.almox_fn_sync_funcao();
CREATE TRIGGER almox_trg_trein_uni BEFORE INSERT OR UPDATE ON public.almox_treinamentos_epi FOR EACH ROW EXECUTE FUNCTION public.almox_fn_valida_unidade_funcionario();
CREATE TRIGGER almox_trg_valida_variacao BEFORE INSERT OR UPDATE ON public.almox_variacoes FOR EACH ROW EXECUTE FUNCTION public.almox_fn_valida_variacao();
ALTER TABLE ONLY public.almox_acessos
    ADD CONSTRAINT almox_acessos_unidade_id_fkey FOREIGN KEY (unidade_id) REFERENCES public.almox_unidades(id) ON DELETE CASCADE;
ALTER TABLE ONLY public.almox_acessos
    ADD CONSTRAINT almox_acessos_usuario_id_fkey FOREIGN KEY (usuario_id) REFERENCES public.almox_usuarios(id) ON DELETE CASCADE;
ALTER TABLE ONLY public.almox_categorias
    ADD CONSTRAINT almox_categorias_unidade_id_fkey FOREIGN KEY (unidade_id) REFERENCES public.almox_unidades(id);
ALTER TABLE ONLY public.almox_cobrancas
    ADD CONSTRAINT almox_cobrancas_emprestimo_id_fkey FOREIGN KEY (emprestimo_id) REFERENCES public.almox_emprestimos(id) ON DELETE SET NULL;
ALTER TABLE ONLY public.almox_cobrancas
    ADD CONSTRAINT almox_cobrancas_funcionario_id_fkey FOREIGN KEY (funcionario_id) REFERENCES public.almox_funcionarios(id);
ALTER TABLE ONLY public.almox_cobrancas
    ADD CONSTRAINT almox_cobrancas_unidade_id_fkey FOREIGN KEY (unidade_id) REFERENCES public.almox_unidades(id);
ALTER TABLE ONLY public.almox_cobrancas
    ADD CONSTRAINT almox_cobrancas_usuario_id_fkey FOREIGN KEY (usuario_id) REFERENCES public.almox_usuarios(id);
ALTER TABLE ONLY public.almox_cobrancas
    ADD CONSTRAINT almox_cobrancas_variacao_id_fkey FOREIGN KEY (variacao_id) REFERENCES public.almox_variacoes(id);
ALTER TABLE ONLY public.almox_dotacoes
    ADD CONSTRAINT almox_dotacoes_unidade_id_fkey FOREIGN KEY (unidade_id) REFERENCES public.almox_unidades(id);
ALTER TABLE ONLY public.almox_emprestimo_itens
    ADD CONSTRAINT almox_emprestimo_itens_emprestimo_id_fkey FOREIGN KEY (emprestimo_id) REFERENCES public.almox_emprestimos(id) ON DELETE CASCADE;
ALTER TABLE ONLY public.almox_emprestimo_itens
    ADD CONSTRAINT almox_emprestimo_itens_variacao_id_fkey FOREIGN KEY (variacao_id) REFERENCES public.almox_variacoes(id);
ALTER TABLE ONLY public.almox_emprestimos
    ADD CONSTRAINT almox_emprestimos_funcionario_id_fkey FOREIGN KEY (funcionario_id) REFERENCES public.almox_funcionarios(id);
ALTER TABLE ONLY public.almox_emprestimos
    ADD CONSTRAINT almox_emprestimos_unidade_id_fkey FOREIGN KEY (unidade_id) REFERENCES public.almox_unidades(id);
ALTER TABLE ONLY public.almox_emprestimos
    ADD CONSTRAINT almox_emprestimos_usuario_id_fkey FOREIGN KEY (usuario_id) REFERENCES public.almox_usuarios(id);
ALTER TABLE ONLY public.almox_fornecedores
    ADD CONSTRAINT almox_fornecedores_unidade_id_fkey FOREIGN KEY (unidade_id) REFERENCES public.almox_unidades(id);
ALTER TABLE ONLY public.almox_funcionarios
    ADD CONSTRAINT almox_funcionarios_funcao_id_fkey FOREIGN KEY (funcao_id) REFERENCES public.almox_funcoes(id);
ALTER TABLE ONLY public.almox_funcionarios
    ADD CONSTRAINT almox_funcionarios_unidade_id_fkey FOREIGN KEY (unidade_id) REFERENCES public.almox_unidades(id);
ALTER TABLE ONLY public.almox_funcoes
    ADD CONSTRAINT almox_funcoes_unidade_id_fkey FOREIGN KEY (unidade_id) REFERENCES public.almox_unidades(id) ON DELETE CASCADE;
ALTER TABLE ONLY public.almox_grades
    ADD CONSTRAINT almox_grades_unidade_id_fkey FOREIGN KEY (unidade_id) REFERENCES public.almox_unidades(id);
ALTER TABLE ONLY public.almox_inventario_itens
    ADD CONSTRAINT almox_inventario_itens_inventario_id_fkey FOREIGN KEY (inventario_id) REFERENCES public.almox_inventarios(id) ON DELETE CASCADE;
ALTER TABLE ONLY public.almox_inventario_itens
    ADD CONSTRAINT almox_inventario_itens_variacao_id_fkey FOREIGN KEY (variacao_id) REFERENCES public.almox_variacoes(id);
ALTER TABLE ONLY public.almox_inventarios
    ADD CONSTRAINT almox_inventarios_categoria_id_fkey FOREIGN KEY (categoria_id) REFERENCES public.almox_categorias(id);
ALTER TABLE ONLY public.almox_inventarios
    ADD CONSTRAINT almox_inventarios_unidade_id_fkey FOREIGN KEY (unidade_id) REFERENCES public.almox_unidades(id);
ALTER TABLE ONLY public.almox_inventarios
    ADD CONSTRAINT almox_inventarios_usuario_id_fkey FOREIGN KEY (usuario_id) REFERENCES public.almox_usuarios(id);
ALTER TABLE ONLY public.almox_itens
    ADD CONSTRAINT almox_itens_categoria_id_fkey FOREIGN KEY (categoria_id) REFERENCES public.almox_categorias(id);
ALTER TABLE ONLY public.almox_itens
    ADD CONSTRAINT almox_itens_grade_id_fkey FOREIGN KEY (grade_id) REFERENCES public.almox_grades(id);
ALTER TABLE ONLY public.almox_itens
    ADD CONSTRAINT almox_itens_unidade_id_fkey FOREIGN KEY (unidade_id) REFERENCES public.almox_unidades(id);
ALTER TABLE ONLY public.almox_movimentacoes
    ADD CONSTRAINT almox_movimentacoes_emprestimo_id_fkey FOREIGN KEY (emprestimo_id) REFERENCES public.almox_emprestimos(id) ON DELETE SET NULL;
ALTER TABLE ONLY public.almox_movimentacoes
    ADD CONSTRAINT almox_movimentacoes_fornecedor_id_fkey FOREIGN KEY (fornecedor_id) REFERENCES public.almox_fornecedores(id);
ALTER TABLE ONLY public.almox_movimentacoes
    ADD CONSTRAINT almox_movimentacoes_funcionario_id_fkey FOREIGN KEY (funcionario_id) REFERENCES public.almox_funcionarios(id);
ALTER TABLE ONLY public.almox_movimentacoes
    ADD CONSTRAINT almox_movimentacoes_inventario_id_fkey FOREIGN KEY (inventario_id) REFERENCES public.almox_inventarios(id) ON DELETE SET NULL;
ALTER TABLE ONLY public.almox_movimentacoes
    ADD CONSTRAINT almox_movimentacoes_remessa_id_fkey FOREIGN KEY (remessa_id) REFERENCES public.almox_remessas_lavanderia(id) ON DELETE SET NULL;
ALTER TABLE ONLY public.almox_movimentacoes
    ADD CONSTRAINT almox_movimentacoes_unidade_id_fkey FOREIGN KEY (unidade_id) REFERENCES public.almox_unidades(id);
ALTER TABLE ONLY public.almox_movimentacoes
    ADD CONSTRAINT almox_movimentacoes_usuario_id_fkey FOREIGN KEY (usuario_id) REFERENCES public.almox_usuarios(id);
ALTER TABLE ONLY public.almox_movimentacoes
    ADD CONSTRAINT almox_movimentacoes_variacao_id_fkey FOREIGN KEY (variacao_id) REFERENCES public.almox_variacoes(id);
ALTER TABLE ONLY public.almox_parametros
    ADD CONSTRAINT almox_parametros_unidade_id_fkey FOREIGN KEY (unidade_id) REFERENCES public.almox_unidades(id);
ALTER TABLE ONLY public.almox_remessa_itens
    ADD CONSTRAINT almox_remessa_itens_remessa_id_fkey FOREIGN KEY (remessa_id) REFERENCES public.almox_remessas_lavanderia(id) ON DELETE CASCADE;
ALTER TABLE ONLY public.almox_remessa_itens
    ADD CONSTRAINT almox_remessa_itens_variacao_id_fkey FOREIGN KEY (variacao_id) REFERENCES public.almox_variacoes(id);
ALTER TABLE ONLY public.almox_remessas_lavanderia
    ADD CONSTRAINT almox_remessas_lavanderia_fornecedor_id_fkey FOREIGN KEY (fornecedor_id) REFERENCES public.almox_fornecedores(id);
ALTER TABLE ONLY public.almox_remessas_lavanderia
    ADD CONSTRAINT almox_remessas_lavanderia_unidade_id_fkey FOREIGN KEY (unidade_id) REFERENCES public.almox_unidades(id);
ALTER TABLE ONLY public.almox_remessas_lavanderia
    ADD CONSTRAINT almox_remessas_lavanderia_usuario_id_fkey FOREIGN KEY (usuario_id) REFERENCES public.almox_usuarios(id);
ALTER TABLE ONLY public.almox_setores
    ADD CONSTRAINT almox_setores_unidade_id_fkey FOREIGN KEY (unidade_id) REFERENCES public.almox_unidades(id) ON DELETE CASCADE;
ALTER TABLE ONLY public.almox_tamanhos
    ADD CONSTRAINT almox_tamanhos_grade_id_fkey FOREIGN KEY (grade_id) REFERENCES public.almox_grades(id) ON DELETE CASCADE;
ALTER TABLE ONLY public.almox_tamanhos
    ADD CONSTRAINT almox_tamanhos_unidade_id_fkey FOREIGN KEY (unidade_id) REFERENCES public.almox_unidades(id);
ALTER TABLE ONLY public.almox_treinamentos_epi
    ADD CONSTRAINT almox_treinamentos_epi_funcionario_id_fkey FOREIGN KEY (funcionario_id) REFERENCES public.almox_funcionarios(id) ON DELETE CASCADE;
ALTER TABLE ONLY public.almox_treinamentos_epi
    ADD CONSTRAINT almox_treinamentos_epi_unidade_id_fkey FOREIGN KEY (unidade_id) REFERENCES public.almox_unidades(id) ON DELETE CASCADE;
ALTER TABLE ONLY public.almox_treinamentos_epi
    ADD CONSTRAINT almox_treinamentos_epi_usuario_id_fkey FOREIGN KEY (usuario_id) REFERENCES public.almox_usuarios(id);
ALTER TABLE ONLY public.almox_usuarios
    ADD CONSTRAINT almox_usuarios_id_fkey FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE;
ALTER TABLE ONLY public.almox_usuarios
    ADD CONSTRAINT almox_usuarios_unidade_id_fkey FOREIGN KEY (unidade_id) REFERENCES public.almox_unidades(id);
ALTER TABLE ONLY public.almox_variacoes
    ADD CONSTRAINT almox_variacoes_item_id_fkey FOREIGN KEY (item_id) REFERENCES public.almox_itens(id) ON DELETE CASCADE;
ALTER TABLE ONLY public.almox_variacoes
    ADD CONSTRAINT almox_variacoes_tamanho_id_fkey FOREIGN KEY (tamanho_id) REFERENCES public.almox_tamanhos(id);
ALTER TABLE ONLY public.almox_variacoes
    ADD CONSTRAINT almox_variacoes_unidade_id_fkey FOREIGN KEY (unidade_id) REFERENCES public.almox_unidades(id);
