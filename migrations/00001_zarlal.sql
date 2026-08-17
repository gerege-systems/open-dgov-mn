-- Энэ байрлуулалтын өөрийн түүх.
--
-- Цөмийн миграцууд болон энэ файл нэг санд, гэхдээ тусдаа goose хүснэгтэд
-- (MIGRATIONS_TABLE=goose_db_version_dgov) бичигдэнэ: goose нь ажилласан
-- хувилбар бүрд нэг мөр хадгалдаг тул цөмийн 00001 ба эндэх 00001 нэг мөр
-- болж, хоёр дахь нь "аль хэдийн ажилласан" гэж тэмдэглэгдэх байлаа.

-- +goose Up
CREATE TABLE IF NOT EXISTS dgov_announcement (
    id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id  UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    title      VARCHAR(200) NOT NULL,
    body       TEXT NOT NULL,
    pinned     BOOLEAN NOT NULL DEFAULT FALSE,
    created_by UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    -- NULL нь "хугацаагүй". Жагсаалт нь энэ баганаар шүүдэг тул хугацаа нь
    -- өнгөрсөн мөр устдаггүй, зүгээр л харагдахаа болино.
    expires_at TIMESTAMPTZ
);

-- Жагсаалтын дараалал болон шүүлт хоёулаа энэ индексээр явна.
CREATE INDEX IF NOT EXISTS idx_dgov_announcement_tenant
    ON dgov_announcement (tenant_id, pinned DESC, created_at DESC);

-- Байгууллагын тусгаарлалт — цөмийн 00029 тэр үед байсан бүх хүснэгт дээр
-- бичсэн яг тэр бодлого. Шинэ хүснэгт түүнд хамрагдахгүй (тэр давталт нэг л
-- удаа ажилласан) тул хүснэгт нэмдэг түүх бүр энэ блокийг өөртөө авч явна.
--
-- Хүснэгтийн эрхийг (GRANT) энд бичээгүй нь санаатай: 00029-ийн ALTER DEFAULT
-- PRIVILEGES нь postgres-ийн үүсгэсэн шинэ хүснэгт бүрийг gerege_nexus_app
-- рүү аль хэдийн нээж өгдөг.
-- +goose StatementBegin
DO $rls$
BEGIN
    EXECUTE 'ALTER TABLE public.dgov_announcement ENABLE ROW LEVEL SECURITY';
    EXECUTE 'ALTER TABLE public.dgov_announcement FORCE ROW LEVEL SECURITY';
    EXECUTE 'DROP POLICY IF EXISTS tenant_isolation ON public.dgov_announcement';
    EXECUTE
        'CREATE POLICY tenant_isolation ON public.dgov_announcement TO gerege_nexus_app '
        'USING (tenant_id = NULLIF(current_setting(''app.current_tenant'', true), '''')::uuid) '
        'WITH CHECK (tenant_id = NULLIF(current_setting(''app.current_tenant'', true), '''')::uuid)';
END
$rls$;
-- +goose StatementEnd

-- +goose Down
DROP TABLE IF EXISTS dgov_announcement;
