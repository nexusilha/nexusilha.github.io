SET check_function_bodies = false;
ALTER TABLE public.almox_acessos ENABLE ROW LEVEL SECURITY;
CREATE POLICY almox_acessos_del ON public.almox_acessos FOR DELETE TO authenticated USING (public.almox_gestor_unidade(unidade_id));
CREATE POLICY almox_acessos_ins ON public.almox_acessos FOR INSERT TO authenticated WITH CHECK (public.almox_gestor_unidade(unidade_id));
CREATE POLICY almox_acessos_sel ON public.almox_acessos FOR SELECT TO authenticated USING (((usuario_id = auth.uid()) OR public.almox_gestor_unidade(unidade_id)));
CREATE POLICY almox_acessos_upd ON public.almox_acessos FOR UPDATE TO authenticated USING (public.almox_gestor_unidade(unidade_id)) WITH CHECK (public.almox_gestor_unidade(unidade_id));
ALTER TABLE public.almox_categorias ENABLE ROW LEVEL SECURITY;
CREATE POLICY almox_categorias_del ON public.almox_categorias FOR DELETE TO authenticated USING (public.almox_gestor_unidade(unidade_id));
CREATE POLICY almox_categorias_ins ON public.almox_categorias FOR INSERT TO authenticated WITH CHECK (public.almox_gestor_unidade(unidade_id));
CREATE POLICY almox_categorias_sel ON public.almox_categorias FOR SELECT TO authenticated USING (public.almox_ve_unidade(unidade_id));
CREATE POLICY almox_categorias_upd ON public.almox_categorias FOR UPDATE TO authenticated USING (public.almox_gestor_unidade(unidade_id)) WITH CHECK (public.almox_gestor_unidade(unidade_id));
ALTER TABLE public.almox_cobrancas ENABLE ROW LEVEL SECURITY;
CREATE POLICY almox_cobrancas_ins ON public.almox_cobrancas FOR INSERT TO authenticated WITH CHECK (public.almox_opera_unidade(unidade_id));
CREATE POLICY almox_cobrancas_sel ON public.almox_cobrancas FOR SELECT TO authenticated USING (public.almox_ve_unidade(unidade_id));
CREATE POLICY almox_cobrancas_upd ON public.almox_cobrancas FOR UPDATE TO authenticated USING (public.almox_gestor_unidade(unidade_id)) WITH CHECK (public.almox_gestor_unidade(unidade_id));
ALTER TABLE public.almox_contadores ENABLE ROW LEVEL SECURITY;
CREATE POLICY almox_contadores_ins ON public.almox_contadores FOR INSERT TO authenticated WITH CHECK (public.almox_pode_ler());
CREATE POLICY almox_contadores_sel ON public.almox_contadores FOR SELECT TO authenticated USING (public.almox_pode_ler());
CREATE POLICY almox_contadores_upd ON public.almox_contadores FOR UPDATE TO authenticated USING (public.almox_pode_ler()) WITH CHECK (public.almox_pode_ler());
ALTER TABLE public.almox_dotacoes ENABLE ROW LEVEL SECURITY;
CREATE POLICY almox_dotacoes_del ON public.almox_dotacoes FOR DELETE TO authenticated USING (public.almox_gestor_unidade(unidade_id));
CREATE POLICY almox_dotacoes_ins ON public.almox_dotacoes FOR INSERT TO authenticated WITH CHECK (public.almox_gestor_unidade(unidade_id));
CREATE POLICY almox_dotacoes_sel ON public.almox_dotacoes FOR SELECT TO authenticated USING (public.almox_ve_unidade(unidade_id));
CREATE POLICY almox_dotacoes_upd ON public.almox_dotacoes FOR UPDATE TO authenticated USING (public.almox_gestor_unidade(unidade_id)) WITH CHECK (public.almox_gestor_unidade(unidade_id));
ALTER TABLE public.almox_emprestimo_itens ENABLE ROW LEVEL SECURITY;
CREATE POLICY almox_emprestimo_itens_del ON public.almox_emprestimo_itens FOR DELETE TO authenticated USING ((EXISTS ( SELECT 1
   FROM public.almox_emprestimos e
  WHERE ((e.id = almox_emprestimo_itens.emprestimo_id) AND public.almox_gestor_unidade(e.unidade_id)))));
CREATE POLICY almox_emprestimo_itens_ins ON public.almox_emprestimo_itens FOR INSERT TO authenticated WITH CHECK ((EXISTS ( SELECT 1
   FROM public.almox_emprestimos e
  WHERE ((e.id = almox_emprestimo_itens.emprestimo_id) AND public.almox_opera_unidade(e.unidade_id)))));
CREATE POLICY almox_emprestimo_itens_sel ON public.almox_emprestimo_itens FOR SELECT TO authenticated USING ((EXISTS ( SELECT 1
   FROM public.almox_emprestimos e
  WHERE ((e.id = almox_emprestimo_itens.emprestimo_id) AND public.almox_ve_unidade(e.unidade_id)))));
CREATE POLICY almox_emprestimo_itens_upd ON public.almox_emprestimo_itens FOR UPDATE TO authenticated USING ((EXISTS ( SELECT 1
   FROM public.almox_emprestimos e
  WHERE ((e.id = almox_emprestimo_itens.emprestimo_id) AND public.almox_opera_unidade(e.unidade_id))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM public.almox_emprestimos e
  WHERE ((e.id = almox_emprestimo_itens.emprestimo_id) AND public.almox_opera_unidade(e.unidade_id)))));
ALTER TABLE public.almox_emprestimos ENABLE ROW LEVEL SECURITY;
CREATE POLICY almox_emprestimos_ins ON public.almox_emprestimos FOR INSERT TO authenticated WITH CHECK (public.almox_opera_unidade(unidade_id));
CREATE POLICY almox_emprestimos_sel ON public.almox_emprestimos FOR SELECT TO authenticated USING (public.almox_ve_unidade(unidade_id));
CREATE POLICY almox_emprestimos_upd ON public.almox_emprestimos FOR UPDATE TO authenticated USING (public.almox_opera_unidade(unidade_id)) WITH CHECK (public.almox_opera_unidade(unidade_id));
ALTER TABLE public.almox_fornecedores ENABLE ROW LEVEL SECURITY;
CREATE POLICY almox_fornecedores_del ON public.almox_fornecedores FOR DELETE TO authenticated USING (public.almox_gestor_unidade(unidade_id));
CREATE POLICY almox_fornecedores_ins ON public.almox_fornecedores FOR INSERT TO authenticated WITH CHECK (public.almox_gestor_unidade(unidade_id));
CREATE POLICY almox_fornecedores_sel ON public.almox_fornecedores FOR SELECT TO authenticated USING (public.almox_ve_unidade(unidade_id));
CREATE POLICY almox_fornecedores_upd ON public.almox_fornecedores FOR UPDATE TO authenticated USING (public.almox_gestor_unidade(unidade_id)) WITH CHECK (public.almox_gestor_unidade(unidade_id));
ALTER TABLE public.almox_funcionarios ENABLE ROW LEVEL SECURITY;
CREATE POLICY almox_funcionarios_del ON public.almox_funcionarios FOR DELETE TO authenticated USING (public.almox_gestor_unidade(unidade_id));
CREATE POLICY almox_funcionarios_ins ON public.almox_funcionarios FOR INSERT TO authenticated WITH CHECK (public.almox_gestor_unidade(unidade_id));
CREATE POLICY almox_funcionarios_sel ON public.almox_funcionarios FOR SELECT TO authenticated USING (public.almox_ve_unidade(unidade_id));
CREATE POLICY almox_funcionarios_upd ON public.almox_funcionarios FOR UPDATE TO authenticated USING (public.almox_gestor_unidade(unidade_id)) WITH CHECK (public.almox_gestor_unidade(unidade_id));
ALTER TABLE public.almox_funcoes ENABLE ROW LEVEL SECURITY;
CREATE POLICY almox_funcoes_del ON public.almox_funcoes FOR DELETE TO authenticated USING (public.almox_gestor_unidade(unidade_id));
CREATE POLICY almox_funcoes_ins ON public.almox_funcoes FOR INSERT TO authenticated WITH CHECK (public.almox_gestor_unidade(unidade_id));
CREATE POLICY almox_funcoes_sel ON public.almox_funcoes FOR SELECT TO authenticated USING (public.almox_ve_unidade(unidade_id));
CREATE POLICY almox_funcoes_upd ON public.almox_funcoes FOR UPDATE TO authenticated USING (public.almox_gestor_unidade(unidade_id)) WITH CHECK (public.almox_gestor_unidade(unidade_id));
ALTER TABLE public.almox_grades ENABLE ROW LEVEL SECURITY;
CREATE POLICY almox_grades_del ON public.almox_grades FOR DELETE TO authenticated USING (public.almox_gestor_unidade(unidade_id));
CREATE POLICY almox_grades_ins ON public.almox_grades FOR INSERT TO authenticated WITH CHECK (public.almox_gestor_unidade(unidade_id));
CREATE POLICY almox_grades_sel ON public.almox_grades FOR SELECT TO authenticated USING (public.almox_ve_unidade(unidade_id));
CREATE POLICY almox_grades_upd ON public.almox_grades FOR UPDATE TO authenticated USING (public.almox_gestor_unidade(unidade_id)) WITH CHECK (public.almox_gestor_unidade(unidade_id));
ALTER TABLE public.almox_inventario_itens ENABLE ROW LEVEL SECURITY;
CREATE POLICY almox_inventario_itens_del ON public.almox_inventario_itens FOR DELETE TO authenticated USING ((EXISTS ( SELECT 1
   FROM public.almox_inventarios x
  WHERE ((x.id = almox_inventario_itens.inventario_id) AND public.almox_gestor_unidade(x.unidade_id)))));
CREATE POLICY almox_inventario_itens_ins ON public.almox_inventario_itens FOR INSERT TO authenticated WITH CHECK ((EXISTS ( SELECT 1
   FROM public.almox_inventarios x
  WHERE ((x.id = almox_inventario_itens.inventario_id) AND public.almox_opera_unidade(x.unidade_id)))));
CREATE POLICY almox_inventario_itens_sel ON public.almox_inventario_itens FOR SELECT TO authenticated USING ((EXISTS ( SELECT 1
   FROM public.almox_inventarios x
  WHERE ((x.id = almox_inventario_itens.inventario_id) AND public.almox_ve_unidade(x.unidade_id)))));
CREATE POLICY almox_inventario_itens_upd ON public.almox_inventario_itens FOR UPDATE TO authenticated USING ((EXISTS ( SELECT 1
   FROM public.almox_inventarios x
  WHERE ((x.id = almox_inventario_itens.inventario_id) AND public.almox_opera_unidade(x.unidade_id))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM public.almox_inventarios x
  WHERE ((x.id = almox_inventario_itens.inventario_id) AND public.almox_opera_unidade(x.unidade_id)))));
ALTER TABLE public.almox_inventarios ENABLE ROW LEVEL SECURITY;
CREATE POLICY almox_inventarios_ins ON public.almox_inventarios FOR INSERT TO authenticated WITH CHECK (public.almox_opera_unidade(unidade_id));
CREATE POLICY almox_inventarios_sel ON public.almox_inventarios FOR SELECT TO authenticated USING (public.almox_ve_unidade(unidade_id));
CREATE POLICY almox_inventarios_upd ON public.almox_inventarios FOR UPDATE TO authenticated USING (public.almox_opera_unidade(unidade_id)) WITH CHECK (public.almox_opera_unidade(unidade_id));
ALTER TABLE public.almox_itens ENABLE ROW LEVEL SECURITY;
CREATE POLICY almox_itens_del ON public.almox_itens FOR DELETE TO authenticated USING (public.almox_gestor_unidade(unidade_id));
CREATE POLICY almox_itens_ins ON public.almox_itens FOR INSERT TO authenticated WITH CHECK (public.almox_gestor_unidade(unidade_id));
CREATE POLICY almox_itens_sel ON public.almox_itens FOR SELECT TO authenticated USING (public.almox_ve_unidade(unidade_id));
CREATE POLICY almox_itens_upd ON public.almox_itens FOR UPDATE TO authenticated USING (public.almox_gestor_unidade(unidade_id)) WITH CHECK (public.almox_gestor_unidade(unidade_id));
ALTER TABLE public.almox_movimentacoes ENABLE ROW LEVEL SECURITY;
CREATE POLICY almox_movimentacoes_ins ON public.almox_movimentacoes FOR INSERT TO authenticated WITH CHECK (public.almox_opera_unidade(unidade_id));
CREATE POLICY almox_movimentacoes_sel ON public.almox_movimentacoes FOR SELECT TO authenticated USING (public.almox_ve_unidade(unidade_id));
ALTER TABLE public.almox_parametros ENABLE ROW LEVEL SECURITY;
CREATE POLICY almox_parametros_del ON public.almox_parametros FOR DELETE TO authenticated USING (public.almox_gestor_unidade(unidade_id));
CREATE POLICY almox_parametros_ins ON public.almox_parametros FOR INSERT TO authenticated WITH CHECK (public.almox_gestor_unidade(unidade_id));
CREATE POLICY almox_parametros_sel ON public.almox_parametros FOR SELECT TO authenticated USING (public.almox_ve_unidade(unidade_id));
CREATE POLICY almox_parametros_upd ON public.almox_parametros FOR UPDATE TO authenticated USING (public.almox_gestor_unidade(unidade_id)) WITH CHECK (public.almox_gestor_unidade(unidade_id));
ALTER TABLE public.almox_remessa_itens ENABLE ROW LEVEL SECURITY;
CREATE POLICY almox_remessa_itens_del ON public.almox_remessa_itens FOR DELETE TO authenticated USING ((EXISTS ( SELECT 1
   FROM public.almox_remessas_lavanderia r
  WHERE ((r.id = almox_remessa_itens.remessa_id) AND public.almox_gestor_unidade(r.unidade_id)))));
CREATE POLICY almox_remessa_itens_ins ON public.almox_remessa_itens FOR INSERT TO authenticated WITH CHECK ((EXISTS ( SELECT 1
   FROM public.almox_remessas_lavanderia r
  WHERE ((r.id = almox_remessa_itens.remessa_id) AND public.almox_opera_unidade(r.unidade_id)))));
CREATE POLICY almox_remessa_itens_sel ON public.almox_remessa_itens FOR SELECT TO authenticated USING ((EXISTS ( SELECT 1
   FROM public.almox_remessas_lavanderia r
  WHERE ((r.id = almox_remessa_itens.remessa_id) AND public.almox_ve_unidade(r.unidade_id)))));
CREATE POLICY almox_remessa_itens_upd ON public.almox_remessa_itens FOR UPDATE TO authenticated USING ((EXISTS ( SELECT 1
   FROM public.almox_remessas_lavanderia r
  WHERE ((r.id = almox_remessa_itens.remessa_id) AND public.almox_opera_unidade(r.unidade_id))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM public.almox_remessas_lavanderia r
  WHERE ((r.id = almox_remessa_itens.remessa_id) AND public.almox_opera_unidade(r.unidade_id)))));
ALTER TABLE public.almox_remessas_lavanderia ENABLE ROW LEVEL SECURITY;
CREATE POLICY almox_remessas_lavanderia_ins ON public.almox_remessas_lavanderia FOR INSERT TO authenticated WITH CHECK (public.almox_opera_unidade(unidade_id));
CREATE POLICY almox_remessas_lavanderia_sel ON public.almox_remessas_lavanderia FOR SELECT TO authenticated USING (public.almox_ve_unidade(unidade_id));
CREATE POLICY almox_remessas_lavanderia_upd ON public.almox_remessas_lavanderia FOR UPDATE TO authenticated USING (public.almox_opera_unidade(unidade_id)) WITH CHECK (public.almox_opera_unidade(unidade_id));
ALTER TABLE public.almox_setores ENABLE ROW LEVEL SECURITY;
CREATE POLICY almox_setores_del ON public.almox_setores FOR DELETE TO authenticated USING (public.almox_gestor_unidade(unidade_id));
CREATE POLICY almox_setores_ins ON public.almox_setores FOR INSERT TO authenticated WITH CHECK (public.almox_gestor_unidade(unidade_id));
CREATE POLICY almox_setores_sel ON public.almox_setores FOR SELECT TO authenticated USING (public.almox_ve_unidade(unidade_id));
CREATE POLICY almox_setores_upd ON public.almox_setores FOR UPDATE TO authenticated USING (public.almox_gestor_unidade(unidade_id)) WITH CHECK (public.almox_gestor_unidade(unidade_id));
ALTER TABLE public.almox_tamanhos ENABLE ROW LEVEL SECURITY;
CREATE POLICY almox_tamanhos_del ON public.almox_tamanhos FOR DELETE TO authenticated USING (public.almox_gestor_unidade(unidade_id));
CREATE POLICY almox_tamanhos_ins ON public.almox_tamanhos FOR INSERT TO authenticated WITH CHECK (public.almox_gestor_unidade(unidade_id));
CREATE POLICY almox_tamanhos_sel ON public.almox_tamanhos FOR SELECT TO authenticated USING (public.almox_ve_unidade(unidade_id));
CREATE POLICY almox_tamanhos_upd ON public.almox_tamanhos FOR UPDATE TO authenticated USING (public.almox_gestor_unidade(unidade_id)) WITH CHECK (public.almox_gestor_unidade(unidade_id));
CREATE POLICY almox_trein_del ON public.almox_treinamentos_epi FOR DELETE TO authenticated USING (public.almox_gestor_unidade(unidade_id));
CREATE POLICY almox_trein_ins ON public.almox_treinamentos_epi FOR INSERT TO authenticated WITH CHECK (public.almox_opera_unidade(unidade_id));
CREATE POLICY almox_trein_sel ON public.almox_treinamentos_epi FOR SELECT TO authenticated USING (public.almox_ve_unidade(unidade_id));
CREATE POLICY almox_trein_upd ON public.almox_treinamentos_epi FOR UPDATE TO authenticated USING (public.almox_gestor_unidade(unidade_id)) WITH CHECK (public.almox_gestor_unidade(unidade_id));
ALTER TABLE public.almox_treinamentos_epi ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.almox_unidades ENABLE ROW LEVEL SECURITY;
CREATE POLICY almox_unidades_del ON public.almox_unidades FOR DELETE TO authenticated USING (public.almox_admin_sistema());
CREATE POLICY almox_unidades_ins ON public.almox_unidades FOR INSERT TO authenticated WITH CHECK (public.almox_admin_sistema());
CREATE POLICY almox_unidades_sel ON public.almox_unidades FOR SELECT TO authenticated USING (true);
CREATE POLICY almox_unidades_upd ON public.almox_unidades FOR UPDATE TO authenticated USING ((public.almox_admin_sistema() OR public.almox_gestor_unidade(id))) WITH CHECK ((public.almox_admin_sistema() OR public.almox_gestor_unidade(id)));
ALTER TABLE public.almox_usuarios ENABLE ROW LEVEL SECURITY;
CREATE POLICY almox_usuarios_sel ON public.almox_usuarios FOR SELECT TO authenticated USING (((id = auth.uid()) OR (EXISTS ( SELECT 1
   FROM public.almox_acessos a
  WHERE ((a.usuario_id = almox_usuarios.id) AND public.almox_gestor_unidade(a.unidade_id))))));
CREATE POLICY almox_usuarios_upd ON public.almox_usuarios FOR UPDATE TO authenticated USING ((EXISTS ( SELECT 1
   FROM public.almox_acessos a
  WHERE ((a.usuario_id = almox_usuarios.id) AND public.almox_gestor_unidade(a.unidade_id))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM public.almox_acessos a
  WHERE ((a.usuario_id = almox_usuarios.id) AND public.almox_gestor_unidade(a.unidade_id)))));
ALTER TABLE public.almox_variacoes ENABLE ROW LEVEL SECURITY;
CREATE POLICY almox_variacoes_del ON public.almox_variacoes FOR DELETE TO authenticated USING (public.almox_gestor_unidade(unidade_id));
CREATE POLICY almox_variacoes_ins ON public.almox_variacoes FOR INSERT TO authenticated WITH CHECK (public.almox_gestor_unidade(unidade_id));
CREATE POLICY almox_variacoes_sel ON public.almox_variacoes FOR SELECT TO authenticated USING (public.almox_ve_unidade(unidade_id));
CREATE POLICY almox_variacoes_upd ON public.almox_variacoes FOR UPDATE TO authenticated USING (public.almox_gestor_unidade(unidade_id)) WITH CHECK (public.almox_gestor_unidade(unidade_id));
