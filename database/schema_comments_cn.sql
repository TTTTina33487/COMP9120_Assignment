-- ============================================================
-- Remote Education Resource Allocation Platform
-- schema.sql 中文数据库注释
--
-- 使用方法：先执行 schema.sql，再执行本文件。
-- 本文件不会修改表结构或数据，只会把中文说明保存到 PostgreSQL
-- 的表和字段元数据中。可在 pgAdmin 的 Properties/Comment 中查看。
-- ============================================================

BEGIN;

SET search_path TO remote_education, public;

-- ============================================================
-- 1. 教育地区、学校及用户
-- ============================================================

COMMENT ON TABLE region IS
'地区信息，用于描述学校所在地区的偏远程度、网络条件和支持优先级。';
COMMENT ON COLUMN region.region_id IS '地区主键，由 PostgreSQL 自动生成。';
COMMENT ON COLUMN region.region_name IS '地区名称，不允许重复。';
COMMENT ON COLUMN region.remoteness_level IS '偏远程度：metropolitan、regional、remote 或 very_remote。';
COMMENT ON COLUMN region.internet_access_level IS '地区整体网络接入水平。';
COMMENT ON COLUMN region.support_priority_level IS '地区获得教育支持的优先级。';

COMMENT ON TABLE school IS
'参与平台的学校；每所学校必须属于一个地区，一个地区可包含多所学校。';
COMMENT ON COLUMN school.school_id IS '学校主键。';
COMMENT ON COLUMN school.region_id IS '外键，指向学校所在的 region。';
COMMENT ON COLUMN school.school_name IS '学校名称；同一地区内不得重名。';
COMMENT ON COLUMN school.school_type IS '学校类型，例如 primary、secondary 或 combined。';

COMMENT ON TABLE coordinator IS
'学校协调员，负责审核学生申请并协助资源分配。';
COMMENT ON COLUMN coordinator.coordinator_id IS '协调员主键。';
COMMENT ON COLUMN coordinator.school_id IS '外键，指向协调员任职的学校。';
COMMENT ON COLUMN coordinator.coordinator_name IS '协调员姓名；同一学校内不得重复。';
COMMENT ON COLUMN coordinator.role IS '协调员在学校或项目中的职责。';

COMMENT ON TABLE student IS
'学生信息；每名学生必须注册在一所学校。';
COMMENT ON COLUMN student.student_id IS '学生主键。';
COMMENT ON COLUMN student.school_id IS '外键，指向学生所在学校。';
COMMENT ON COLUMN student.first_name IS '学生名字。';
COMMENT ON COLUMN student.last_name IS '学生姓氏。';
COMMENT ON COLUMN student.year_level IS '年级，限制为 1 至 13。';
COMMENT ON COLUMN student.has_device IS '学生当前是否拥有可用于线上学习的设备。';
COMMENT ON COLUMN student.internet_access_level IS '学生个人网络接入水平。';

-- ============================================================
-- 2. 资格类型及学生资格（M:N）
-- ============================================================

COMMENT ON TABLE eligibility_type IS
'标准化资格类型，避免把相同资格名称作为自由文本重复存储。';
COMMENT ON COLUMN eligibility_type.eligibility_type_id IS '资格类型主键。';
COMMENT ON COLUMN eligibility_type.type_name IS '资格类型名称，不允许重复。';
COMMENT ON COLUMN eligibility_type.description IS '资格类型的详细说明。';

COMMENT ON TABLE student_eligibility IS
'学生与资格类型之间的多对多关联表，同时记录验证状态和有效期。';
COMMENT ON COLUMN student_eligibility.student_id IS '联合主键及外键，指向 student。';
COMMENT ON COLUMN student_eligibility.eligibility_type_id IS '联合主键及外键，指向 eligibility_type。';
COMMENT ON COLUMN student_eligibility.verified_date IS '资格完成验证的日期；状态为 verified 时不能为空。';
COMMENT ON COLUMN student_eligibility.expiry_date IS '资格到期日；如填写，不得早于验证日期。';
COMMENT ON COLUMN student_eligibility.verification_status IS '验证状态：pending、verified、rejected 或 expired。';

-- ============================================================
-- 3. 组织 ISA 层次、资源提供及资助
-- ============================================================

COMMENT ON TABLE organisation IS
'所有外部组织的共同父实体，保存组织名称和联系方式。';
COMMENT ON COLUMN organisation.organisation_id IS '组织主键。';
COMMENT ON COLUMN organisation.organisation_name IS '组织名称，不允许重复。';
COMMENT ON COLUMN organisation.contact_email IS '组织联系邮箱，不允许重复并进行基本格式检查。';

COMMENT ON TABLE provider IS
'organisation 的资源提供方子类型；主键同时是指向 organisation 的外键。';
COMMENT ON COLUMN provider.organisation_id IS '提供方主键及 organisation 外键。';

COMMENT ON TABLE funder IS
'organisation 的资金提供方子类型；同一组织可以同时是 provider 和 funder。';
COMMENT ON COLUMN funder.organisation_id IS '资助方主键及 organisation 外键。';

COMMENT ON TABLE resource_offering IS
'资源提供方发布的可申请教育资源，包含数量、学科、到期日和资格要求。';
COMMENT ON COLUMN resource_offering.offering_id IS '资源项目主键。';
COMMENT ON COLUMN resource_offering.provider_id IS '外键，指向发布资源的 provider。';
COMMENT ON COLUMN resource_offering.required_eligibility_type_id IS '可空外键；该资源要求的资格类型。为空表示无特定资格要求。';
COMMENT ON COLUMN resource_offering.resource_name IS '资源名称。';
COMMENT ON COLUMN resource_offering.resource_type IS '资源类别，例如 device、course 或 tutoring。';
COMMENT ON COLUMN resource_offering.subject_area IS '资源对应的学科领域。';
COMMENT ON COLUMN resource_offering.total_quantity IS '资源总容量，必须大于零。';
COMMENT ON COLUMN resource_offering.expiry_date IS '资源项目停止接受或处理申请的日期。';

COMMENT ON TABLE resource_funding IS
'资源项目与资助方之间的多对多关联表；一个项目可由多个组织资助。';
COMMENT ON COLUMN resource_funding.offering_id IS '联合主键及外键，指向 resource_offering。';
COMMENT ON COLUMN resource_funding.funder_id IS '联合主键及外键，指向 funder。';

-- ============================================================
-- 4. 申请、审核和部分分配
-- ============================================================

COMMENT ON TABLE application IS
'学生对某项资源提交的申请；当前设计允许每份申请最多保存一次审核决定。';
COMMENT ON COLUMN application.application_id IS '申请主键。';
COMMENT ON COLUMN application.student_id IS '外键，指向提交申请的学生。';
COMMENT ON COLUMN application.offering_id IS '外键，指向被申请的资源项目。';
COMMENT ON COLUMN application.reviewer_id IS '可空外键，指向负责审核的协调员。待审核时可为空。';
COMMENT ON COLUMN application.application_date IS '申请日期，默认使用数据库当前日期。';
COMMENT ON COLUMN application.requested_quantity IS '学生请求的数量，必须大于零。支持后续进行部分分配。';
COMMENT ON COLUMN application.learning_goal IS '学生申请该资源希望实现的学习目标。';
COMMENT ON COLUMN application.priority_level IS '申请优先级：low、medium、high 或 urgent。';
COMMENT ON COLUMN application.decision_status IS '审核状态：pending、under_review、approved、rejected 或 withdrawn。';
COMMENT ON COLUMN application.decision_date IS '作出最终决定或撤回申请的时间。';
COMMENT ON COLUMN application.decision_reason IS '审核说明；拒绝申请时必须填写。';

COMMENT ON TABLE allocation IS
'对已批准申请进行的实际资源分配；同一申请可有多条记录以支持部分或分批分配。';
COMMENT ON COLUMN allocation.allocation_id IS '分配记录主键。';
COMMENT ON COLUMN allocation.application_id IS '外键，指向接受资源分配的申请。';
COMMENT ON COLUMN allocation.allocation_date IS '分配发生的时间，默认使用当前时间。';
COMMENT ON COLUMN allocation.quantity_allocated IS '本次分配数量，必须大于零。';
COMMENT ON COLUMN allocation.allocation_status IS '分配状态：active、completed、cancelled 或 returned。';

COMMENT ON TABLE usage_record IS
'依赖 allocation 存在的弱实体，用于跟踪资源使用、课程进度、出勤或归还情况。';
COMMENT ON COLUMN usage_record.allocation_id IS '所有者主键及外键，指向 allocation。';
COMMENT ON COLUMN usage_record.record_no IS '分配范围内的局部编号，与 allocation_id 共同组成主键。';
COMMENT ON COLUMN usage_record.record_date IS '使用记录日期。';
COMMENT ON COLUMN usage_record.usage_type IS '记录类型，例如 attendance、progress 或 device_return。';
COMMENT ON COLUMN usage_record.usage_status IS '状态：scheduled、in_progress、completed、missed 或 returned。';
COMMENT ON COLUMN usage_record.notes IS '补充说明。';

-- ============================================================
-- 5. 视图
-- ============================================================

COMMENT ON VIEW v_offering_capacity IS
'汇总每项资源的总数量、已分配数量和剩余数量；取消或退回的分配不占用容量。';
COMMENT ON VIEW v_application_fulfilment IS
'汇总每份申请的请求数量、已分配数量和仍待分配数量。';

COMMIT;

-- ============================================================
-- 重要业务规则说明
-- ============================================================
-- 普通 CHECK 约束只能检查当前行，不能安全计算其他分配记录的合计。
-- 因此以下两条跨行规则必须由业务事务实现：
-- 1. 同一申请的有效分配总量不得超过 application.requested_quantity；
-- 2. 同一资源项目的有效分配总量不得超过 resource_offering.total_quantity。
-- 分配事务应锁定对应的 application 和 resource_offering 行，重新计算合计，
-- 验证两条规则后再插入 allocation；任何步骤失败都必须 ROLLBACK。
