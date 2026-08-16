#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
FutureWay - Decision Tree
รับ input: คำตอบแบบทดสอบ MBTI (หรือรหัส MBTI ที่คำนวณแล้ว)
ส่ง output: JSON สาขาที่แนะนำ 3 อันดับ (คิดคะแนนจาก MBTI 100%)
"""

import sys
import os

# บังคับให้ stdout/stderr เป็น UTF-8 เสมอ ไม่ว่า console/PHP proc_open
# จะรันด้วย encoding อะไรก็ตาม (แก้ปัญหา 'charmap' codec can't encode
# ตอน print ตัวอักษรไทยหรืออีโมจิ เช่น ⭐ ออกไปให้ PHP อ่าน)
sys.stdout.reconfigure(encoding='utf-8')
sys.stderr.reconfigure(encoding='utf-8')

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), 'python_libs'))
import json
import mysql.connector

# ========================================
# ตั้งค่าเชื่อมต่อ Database
# อ่านจาก environment variable ของ Railway ก่อน (ชุดเดียวกับ php/db_config.php)
# -> ย้ายไป Railway account ใหม่ได้โดยไม่ต้องแก้โค้ด แค่ผูกตัวแปร MYSQL* ให้ service
# ========================================
DB_CONFIG = {
    'host':     os.getenv('MYSQLHOST')     or 'mysql.railway.internal',
    'port':     int(os.getenv('MYSQLPORT') or 3306),
    'user':     os.getenv('MYSQLUSER')     or 'root',
    'password': os.getenv('MYSQLPASSWORD') or '',
    'database': os.getenv('MYSQLDATABASE') or 'railway'  # ต้องตรงกับ DB ที่ไฟล์ PHP ทุกไฟล์ใช้
}

# ========================================
# MBTI Decision Tree (หัวข้อที่ 3)
# ========================================
def get_mbti_questions():
    """
    ดึงคำถาม MBTI ทั้งหมดจากตาราง mbti_questions
    โครงสร้างตาราง: id, category (EI/SN/TF/JP), question_no, question_text,
                    option_a_text, option_a_trait, option_b_text, option_b_trait
    """
    conn   = mysql.connector.connect(**DB_CONFIG)
    cursor = conn.cursor(dictionary=True)
    cursor.execute("SELECT * FROM mbti_questions ORDER BY category, question_no")
    questions = cursor.fetchall()
    cursor.close()
    conn.close()
    return questions


def resolve_mbti_from_answers(answers):
    """
    รับคำตอบของผู้ใช้ แล้วคำนวณรหัส MBTI 4 ตัวอักษร
    ตามหลัก Decision Tree (นับคะแนนเสียงข้างมากในแต่ละมิติ EI / SN / TF / JP)

    answers: list of dict เช่น
        [{'question_id': 1, 'selected': 'A'}, {'question_id': 2, 'selected': 'B'}, ...]
        - question_id ต้องตรงกับ id ในตาราง mbti_questions
        - selected คือ 'A' หรือ 'B' (ข้อที่ผู้ใช้เลือก)

    คืนค่า: {
        'mbti': 'INTJ',
        'detail': {'EI': {'E': 1, 'I': 2}, 'SN': {...}, 'TF': {...}, 'JP': {...}}
    }
    """
    questions = get_mbti_questions()

    # key ของ map ต้องเป็น str เสมอ เพราะ id ที่ส่งมาจากหน้าเว็บอาจเป็น "1" (string)
    # ได้ ถ้า PHP ดึงด้วย $conn->query() ซึ่งคืนทุกคอลัมน์เป็น string
    # ถ้า key ฝั่งนี้เป็น int จะ .get() ไม่เจอสักข้อ -> คะแนนเป็น 0 ทุกมิติ -> ได้ INFP เสมอ
    q_map = {str(q['id']): q for q in questions}

    # นับคะแนนแยกตามมิติ
    tally = {
        'EI': {'E': 0, 'I': 0},
        'SN': {'S': 0, 'N': 0},
        'TF': {'T': 0, 'F': 0},
        'JP': {'J': 0, 'P': 0},
    }

    matched = 0   # จำนวนคำตอบที่นับเข้าคะแนนได้จริง

    for ans in answers:
        q = q_map.get(str(ans.get('question_id')).strip())
        if not q:
            continue  # ข้ามคำถามที่ไม่พบในฐานข้อมูล

        category = str(q.get('category') or '').strip().upper()   # 'EI'/'SN'/'TF'/'JP'
        selected = str(ans.get('selected') or '').strip().upper() # 'A' หรือ 'B'

        if category not in tally:
            continue

        if selected == 'A':
            trait = str(q.get('option_a_trait') or '').strip().upper()
            fallback = category[0]
        elif selected == 'B':
            trait = str(q.get('option_b_trait') or '').strip().upper()
            fallback = category[1]
        else:
            continue

        # เผื่อ DB เก็บ trait เป็นคำเต็ม ('Introvert') หรือเว้นว่างไว้
        trait = trait[:1] if trait else ''
        if trait not in tally[category]:
            trait = fallback   # A = ตัวอักษรตัวแรกของมิติ, B = ตัวที่สอง

        tally[category][trait] += 1
        matched += 1

    # ทางแยกตัดสินใจ (Decision Tree) ของแต่ละมิติ: เลือกตัวอักษรที่ได้คะแนนมากกว่า
    # ถ้าคะแนนเท่ากันพอดี (tie) จะ default ไปทางฝั่งขวาของมิตินั้น (I, N, F, P)
    tie_break = {'EI': 'I', 'SN': 'N', 'TF': 'F', 'JP': 'P'}

    mbti_code = ''
    for dim in ['EI', 'SN', 'TF', 'JP']:
        counts  = tally[dim]
        letters = list(counts.keys())  # เช่น ['E', 'I']

        if counts[letters[0]] > counts[letters[1]]:
            result_letter = letters[0]
        elif counts[letters[1]] > counts[letters[0]]:
            result_letter = letters[1]
        else:
            result_letter = tie_break[dim]

        mbti_code += result_letter

    return {
        'mbti':    mbti_code,
        'detail':  tally,
        'matched': matched,
        'total':   len(answers)
    }


# ========================================
# Decision Tree Logic
# ========================================
# ----------------------------------------
# สัดส่วนคะแนน: MBTI 100% (ไม่ใช้เกรดในการคำนวณแล้ว)
#
# MBTI ให้คะแนนตาม "ลำดับในลิสต์ mbti_match" ของสาขา (ตัวแรก = เข้ากันที่สุด)
# เพื่อให้สาขาในกลุ่มบุคลิกเดียวกันได้คะแนนลดหลั่น ไม่กองเท่ากันหมด
# ถ้าไม่อยู่ในลิสต์เลย ให้คะแนนตามจำนวนตัวอักษร MBTI ที่ตรงบางส่วน
# ----------------------------------------
MBTI_POSITION_SCORES = [100, 90, 80, 70, 60]  # คะแนนตามลำดับใน mbti_match
MBTI_PARTIAL_MAX     = 50   # ไม่อยู่ในลิสต์: (ตัวอักษรตรงมากสุด/4) x ค่านี้ (ตรง 3/4 = 37.5)


def calculate_score(branch, mbti):
    """
    คำนวณคะแนนความเหมาะสมของสาขา (0-100) จาก MBTI ล้วนๆ

    สูตร (MBTI 100%):
    1. MBTI อยู่ในลิสต์ของสาขา ได้ตามลำดับความเข้ากัน 100/90/80/70/60
    2. ไม่อยู่ในลิสต์ ได้ตามตัวอักษรที่ตรงบางส่วน สูงสุด 50
    """
    score = 0

    mbti_match = json.loads(branch['mbti_match']) if isinstance(branch['mbti_match'], str) else branch['mbti_match']

    if mbti in mbti_match:
        # ยิ่งอยู่ต้นลิสต์ = สาขานั้นเข้ากับบุคลิกนี้มากที่สุด ได้คะแนนสูงสุด
        idx = mbti_match.index(mbti)
        score += MBTI_POSITION_SCORES[min(idx, len(MBTI_POSITION_SCORES) - 1)]
    else:
        # เช็คว่า match บางมิติไหม
        partial = 0
        for m in mbti_match:
            match_count = sum(1 for a, b in zip(mbti, m) if a == b)
            partial = max(partial, match_count)
        score += (partial / 4) * MBTI_PARTIAL_MAX

    return round(max(0, min(100, score)), 2)


def run_decision_tree(mbti):
    """
    รัน Decision Tree หลัก
    ส่งคืน top 3 สาขาที่เหมาะสมที่สุด
    """
    try:
        conn   = mysql.connector.connect(**DB_CONFIG)
        cursor = conn.cursor(dictionary=True)
        
        cursor.execute("SELECT * FROM branches WHERE is_active = 1")
        branches = cursor.fetchall()
        cursor.close()
        conn.close()
        
    except Exception as e:
        return {"error": str(e)}

    if not branches:
        return {"error": "ไม่พบสาขาในตาราง branches (ตารางว่าง หรือไม่มีแถวที่ is_active = 1)"}

    # คำนวณคะแนนทุกสาขา
    results = []
    for branch in branches:
        score = calculate_score(branch, mbti)
        results.append({
            'id':          branch['id'],
            'name':        branch['name'],
            'faculty':     branch['faculty'],
            'description': branch['description'],
            'score':       score
        })

    # เรียงคะแนนจากมากไปน้อย เอา top 3
    results.sort(key=lambda x: x['score'], reverse=True)
    top3 = results[:3]

    return {
        'mbti':      mbti,
        # จำนวนสาขาทั้งหมดที่ถูกคำนวณคะแนนในรอบนี้ (ทุกแถว is_active = 1)
        # ไว้เช็คได้ว่าข้อมูลสาขาชุดใหม่ถูกนำมาคิดครบจริง
        'branches_considered': len(results),
        'top3':      top3
    }


# ========================================
# Main — รับ argument จาก PHP
# ========================================
if __name__ == '__main__':
    try:
        # รับ JSON จาก PHP ผ่าน stdin
        input_data = sys.stdin.read()
        data       = json.loads(input_data)

        # หมายเหตุ: ไม่ใช้เกรดในการคำนวณแล้ว (MBTI 100%)
        # ถ้า caller เก่ายังส่ง data['grades'] มาด้วย จะถูกเมินเฉยๆ ไม่ error

        mbti_detail = None

        if 'answers' in data:
            # โหมดใหม่: รับคำตอบดิบ [{'question_id':1,'selected':'A'}, ...]
            # แล้วคำนวณรหัส MBTI เองด้วย Decision Tree (หัวข้อที่ 3)
            mbti_result = resolve_mbti_from_answers(data['answers'])

            # ถ้าไม่มีคำตอบข้อไหนนับเข้าคะแนนได้เลย แปลว่า question_id ที่ส่งมา
            # ไม่ตรงกับตาราง mbti_questions -> ต้องแจ้ง error ไม่ใช่ปล่อยให้ tie-break
            # คืนค่า INFP ออกไปเงียบๆ เหมือนเป็นผลลัพธ์จริง
            if mbti_result['matched'] == 0:
                print(json.dumps({
                    'error': 'ไม่สามารถจับคู่คำตอบกับคำถามในฐานข้อมูลได้ '
                             '(question_id ที่ส่งมาไม่ตรงกับตาราง mbti_questions)',
                    'sent_ids': [a.get('question_id') for a in data['answers']]
                }, ensure_ascii=False))
                sys.exit(0)

            mbti        = mbti_result['mbti']
            mbti_detail = mbti_result['detail']
        else:
            # โหมดเดิม: รับรหัส MBTI ที่คำนวณมาแล้ว เช่น 'INTJ'
            mbti = data['mbti']

        result = run_decision_tree(mbti)

        if mbti_detail is not None:
            result['mbti_detail'] = mbti_detail
        
        # ส่ง JSON กลับไปให้ PHP
        print(json.dumps(result, ensure_ascii=False))
        
    except Exception as e:
        print(json.dumps({'error': str(e)}, ensure_ascii=False))
