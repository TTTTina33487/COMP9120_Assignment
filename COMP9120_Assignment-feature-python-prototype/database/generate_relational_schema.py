from pathlib import Path
from PIL import Image, ImageDraw, ImageFont


ROOT = Path('/Users/anzzzzy/Documents/Codex/2026-09-19/zhe')
OUTPUT = ROOT / 'outputs/relational-schema/remote_education_relational_schema.png'
W, H = 3500, 2200

FONT = '/System/Library/Fonts/Supplemental/Arial.ttf'
FONT_BOLD = '/System/Library/Fonts/Supplemental/Arial Bold.ttf'


def f(size, bold=False):
    return ImageFont.truetype(FONT_BOLD if bold else FONT, size=size)


img = Image.new('RGB', (W, H), '#FFFFFF')
d = ImageDraw.Draw(img)

INK = '#17202A'
BLUE = '#17365D'
HEADER = '#D9E7F5'
KEY = '#FFF2CC'
ALT = '#F7F9FC'
LINE = '#5B6573'

row_h = 38
header_h = 56
table_w = 470
tables = {}


def table(name, x, y, fields, width=table_w):
    h = header_h + len(fields) * row_h
    tables[name] = {'box': (x, y, x + width, y + h), 'x': x, 'y': y,
                    'w': width, 'h': h, 'fields': fields}


table('REGION', 80, 170, [
    ('PK', 'region_id'), ('UQ', 'region_name'), ('', 'remoteness_level'),
    ('', 'internet_access_level'), ('', 'support_priority_level')])
table('SCHOOL', 80, 550, [
    ('PK', 'school_id'), ('FK', 'region_id'), ('', 'school_name'), ('', 'school_type'),
    ('UQ', '(region_id, school_name)')])
table('COORDINATOR', 80, 1010, [
    ('PK', 'coordinator_id'), ('FK', 'school_id'), ('', 'coordinator_name'), ('', 'role')])

table('STUDENT', 650, 550, [
    ('PK', 'student_id'), ('FK', 'school_id'), ('', 'first_name'), ('', 'last_name'),
    ('', 'year_level'), ('', 'has_device'), ('', 'internet_access_level')])
table('STUDENT_ELIGIBILITY', 650, 1040, [
    ('PK/FK', 'student_id'), ('PK/FK', 'eligibility_type_id'),
    ('', 'verified_date'), ('', 'expiry_date'), ('', 'verification_status')])
table('ELIGIBILITY_TYPE', 650, 1570, [
    ('PK', 'eligibility_type_id'), ('UQ', 'type_name'), ('', 'description')])

table('ORGANISATION', 1320, 170, [
    ('PK', 'organisation_id'), ('UQ', 'organisation_name'), ('UQ', 'contact_email')])
table('PROVIDER', 1240, 520, [('PK/FK', 'organisation_id')], width=390)
table('FUNDER', 1810, 520, [('PK/FK', 'organisation_id')], width=390)
table('RESOURCE_OFFERING', 1240, 820, [
    ('PK', 'offering_id'), ('FK', 'provider_id'),
    ('FK', 'required_eligibility_type_id (NULL)'), ('', 'resource_name'),
    ('', 'resource_type'), ('', 'subject_area'), ('', 'total_quantity'), ('', 'expiry_date')], width=520)
table('RESOURCE_FUNDING', 1810, 1070, [
    ('PK/FK', 'offering_id'), ('PK/FK', 'funder_id')], width=430)

table('APPLICATION', 2380, 690, [
    ('PK', 'application_id'), ('FK', 'student_id'), ('FK', 'offering_id'),
    ('FK', 'reviewer_id (NULL)'), ('', 'application_date'),
    ('', 'requested_quantity'), ('', 'learning_goal'), ('', 'priority_level'),
    ('', 'decision_status'), ('', 'decision_date (NULL)'), ('', 'decision_reason (NULL)')], width=530)
table('ALLOCATION', 2380, 1440, [
    ('PK', 'allocation_id'), ('FK', 'application_id'), ('', 'allocation_date'),
    ('', 'quantity_allocated'), ('', 'allocation_status')], width=500)
table('USAGE_RECORD', 2960, 1580, [
    ('PK/FK', 'allocation_id'), ('PK', 'record_no (partial key)'),
    ('', 'record_date'), ('', 'usage_type'), ('', 'usage_status'), ('', 'notes (NULL)')], width=470)


def anchor(name, side, frac=0.5):
    t = tables[name]
    x1, y1, x2, y2 = t['box']
    if side == 'left':
        return (x1, y1 + (y2 - y1) * frac)
    if side == 'right':
        return (x2, y1 + (y2 - y1) * frac)
    if side == 'top':
        return (x1 + (x2 - x1) * frac, y1)
    return (x1 + (x2 - x1) * frac, y2)


def relation(points, label, left_card='', right_card=''):
    pts = [(int(x), int(y)) for x, y in points]
    d.line(pts, fill=LINE, width=4, joint='curve')
    # The FK columns already define ordinary relational cardinalities. Only the
    # ISA label is kept on the connector so the diagram remains readable.
    if label.startswith('ISA'):
        mid = pts[len(pts) // 2]
        box = d.textbbox((0, 0), label, font=f(22))
        tw = box[2] - box[0]
        d.rectangle((mid[0] - tw / 2 - 8, mid[1] - 18,
                     mid[0] + tw / 2 + 8, mid[1] + 14), fill='#FFFFFF')
        d.text((mid[0] - tw / 2, mid[1] - 15), label, font=f(22), fill=INK)


# Relationships are drawn first so table boxes remain visually dominant.
relation([anchor('REGION', 'bottom'), anchor('SCHOOL', 'top')], 'contains', '1', 'N')
relation([anchor('SCHOOL', 'bottom', .25), anchor('COORDINATOR', 'top', .25)], 'employs', '1', 'N')
relation([anchor('SCHOOL', 'right'), anchor('STUDENT', 'left')], 'enrols', '1', 'N')
relation([anchor('STUDENT', 'bottom'), anchor('STUDENT_ELIGIBILITY', 'top')], 'holds', '1', 'N')
relation([anchor('ELIGIBILITY_TYPE', 'top'), anchor('STUDENT_ELIGIBILITY', 'bottom')], 'classifies', '1', 'N')

org_bottom = anchor('ORGANISATION', 'bottom')
relation([org_bottom, (org_bottom[0], 455), (1435, 455), anchor('PROVIDER', 'top')],
         'ISA overlapping', '1', '0..1')
relation([org_bottom, (org_bottom[0], 455), (2005, 455), anchor('FUNDER', 'top')],
         'ISA overlapping', '1', '0..1')
relation([anchor('PROVIDER', 'bottom'), anchor('RESOURCE_OFFERING', 'top', .25)],
         'provides', '1', 'N')
relation([anchor('FUNDER', 'bottom'), anchor('RESOURCE_FUNDING', 'top', .75)],
         'funds', '1', 'N')
relation([anchor('RESOURCE_OFFERING', 'right', .65),
          (1785, anchor('RESOURCE_OFFERING', 'right', .65)[1]),
          (1785, anchor('RESOURCE_FUNDING', 'left')[1]),
          anchor('RESOURCE_FUNDING', 'left')], 'funded through', '1', 'N')
relation([anchor('ELIGIBILITY_TYPE', 'right', .25), (1120, 1635),
          (1120, 1020), anchor('RESOURCE_OFFERING', 'left', .45)],
         'required by', '1', 'N')

relation([anchor('STUDENT', 'right', .35), (2240, anchor('STUDENT', 'right', .35)[1]),
          (2240, anchor('APPLICATION', 'left', .20)[1]), anchor('APPLICATION', 'left', .20)],
         'submits', '1', 'N')
relation([anchor('RESOURCE_OFFERING', 'right', .25),
          anchor('APPLICATION', 'left', .45)], 'requested in', '1', 'N')
relation([anchor('COORDINATOR', 'right', .45), (2260, anchor('COORDINATOR', 'right', .45)[1]),
          (2260, anchor('APPLICATION', 'left', .75)[1]), anchor('APPLICATION', 'left', .75)],
         'reviews', '0..1', 'N')
relation([anchor('APPLICATION', 'bottom'), anchor('ALLOCATION', 'top')],
         'results in', '1', 'N')
relation([anchor('ALLOCATION', 'right'), anchor('USAGE_RECORD', 'left')],
         'identifies', '1', 'N')


def draw_table(name):
    t = tables[name]
    x, y, w, h = t['x'], t['y'], t['w'], t['h']
    d.rectangle((x, y, x + w, y + h), fill='#FFFFFF', outline=BLUE, width=5)
    d.rectangle((x, y, x + w, y + header_h), fill=HEADER, outline=BLUE, width=3)
    d.text((x + 18, y + 12), name, font=f(27, True), fill=INK)
    for i, (kind, field) in enumerate(t['fields']):
        ry = y + header_h + i * row_h
        fill = KEY if kind.startswith('PK') else (ALT if i % 2 else '#FFFFFF')
        d.rectangle((x, ry, x + w, ry + row_h), fill=fill, outline='#C9D2DC', width=2)
        if kind:
            d.text((x + 12, ry + 7), kind, font=f(19, True), fill=BLUE)
        d.text((x + 105, ry + 7), field, font=f(20), fill=INK)


for name in tables:
    draw_table(name)

d.text((80, 55), 'Remote Education Resource Allocation Relational Schema',
       font=f(48, True), fill=INK)
d.text((80, 115),
       'Logical mapping of the revised ER model  •  PostgreSQL schema: remote_education',
       font=f(26), fill='#59636E')

d.text((80, 2100), 'Legend:', font=f(23, True), fill=INK)
d.text((185, 2100),
       'PK = primary key   FK = foreign key   UQ = unique constraint   NULL = optional   line = FK reference',
       font=f(22), fill='#59636E')
d.text((80, 2140),
       'Composite tables STUDENT_ELIGIBILITY and RESOURCE_FUNDING map M:N relationships; '
       'USAGE_RECORD uses the weak entity key (allocation_id, record_no).',
       font=f(22), fill='#7F6000')

OUTPUT.parent.mkdir(parents=True, exist_ok=True)
img.save(OUTPUT, dpi=(240, 240), optimize=True)
print(OUTPUT)
