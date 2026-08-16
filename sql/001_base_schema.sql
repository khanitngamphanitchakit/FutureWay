-- ========================================
-- FutureWay - Migration 001 (base schema)
-- โครงสร้างตารางพื้นฐานทั้งหมด สำหรับติดตั้งบน MySQL เปล่าๆ (เช่น Railway account ใหม่)
--
-- รันซ้ำได้ปลอดภัย: ทุกตารางใช้ CREATE TABLE IF NOT EXISTS
-- และ seed คำถามใช้ INSERT IGNORE (id ซ้ำจะถูกข้าม)
--
-- วิธีรัน: deploy แอปแล้วเปิด php/migrate.php?token=... (ดูหัวไฟล์ migrate.php)
--          หรือ copy ไปรันใน MySQL client ตรงๆ ก็ได้
--
-- ไฟล์ migration ถัดไป (002, 003, ...) จะเติมตาราง/คอลัมน์ที่เหลือเอง
-- ========================================

-- ---- 1) ผู้ใช้ ----
-- phone / address เป็นคอลัมน์ที่ migration 003 เพิ่ม แต่ใส่มาตั้งแต่ต้นเลย
-- (003 รันทับจะเจอ error 1060 ซึ่ง migrate.php ถือว่า "มีอยู่แล้ว" และข้ามให้)
CREATE TABLE IF NOT EXISTS `users` (
  `id`         int(11)      NOT NULL AUTO_INCREMENT,
  `username`   varchar(50)  NOT NULL,
  `firstname`  varchar(100) NOT NULL,
  `lastname`   varchar(100) NOT NULL,
  `gender`     varchar(10)  NOT NULL,
  `email`      varchar(150) NOT NULL,
  `phone`      varchar(20)  DEFAULT NULL,
  `address`    varchar(255) DEFAULT NULL,
  `password`   varchar(255) NOT NULL,
  `created_at` datetime DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `username` (`username`),
  UNIQUE KEY `email` (`email`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---- 2) สาขา ----
-- คอลัมน์ min_* / weight_* คงไว้ตาม schema เดิมเพื่อให้ข้อมูลชุด 006b ลงได้ครบ
-- (การคำนวณคะแนนปัจจุบันใช้ MBTI 100% ไม่ได้ใช้ค่าพวกนี้แล้ว)
CREATE TABLE IF NOT EXISTS `branches` (
  `id`            int(11)      NOT NULL AUTO_INCREMENT,
  `name`          varchar(100) NOT NULL,
  `faculty`       varchar(100) NOT NULL,
  `description`   text,
  `mbti_match`    json         NOT NULL,
  `min_math`      decimal(3,2) DEFAULT '0.00',
  `min_sci`       decimal(3,2) DEFAULT '0.00',
  `min_eng`       decimal(3,2) DEFAULT '0.00',
  `min_thai`      decimal(3,2) DEFAULT '0.00',
  `min_social`    decimal(3,2) DEFAULT '0.00',
  `min_art`       decimal(3,2) DEFAULT '0.00',
  `weight_math`   decimal(3,2) DEFAULT '1.00',
  `weight_sci`    decimal(3,2) DEFAULT '1.00',
  `weight_eng`    decimal(3,2) DEFAULT '1.00',
  `weight_thai`   decimal(3,2) DEFAULT '1.00',
  `weight_social` decimal(3,2) DEFAULT '1.00',
  `weight_art`    decimal(3,2) DEFAULT '1.00',
  `is_active`     tinyint(1)   DEFAULT '1',
  `created_at`    timestamp    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ---- 3) ผลการทำแบบทดสอบ ----
-- รวมคอลัมน์ที่ migration 002 เพิ่ม (avg_grade, mbti_detail, answers_total) มาตั้งแต่ต้น
-- คอลัมน์ grade_* คงไว้เพื่อ backward compat กับประวัติเก่า — ระบบใหม่บันทึก 0.00
CREATE TABLE IF NOT EXISTS `quiz_results` (
  `id`            int(11)      NOT NULL AUTO_INCREMENT,
  `user_id`       int(11)      NOT NULL,
  `grade_math`    decimal(3,2) NOT NULL DEFAULT '0.00',
  `grade_sci`     decimal(3,2) NOT NULL DEFAULT '0.00',
  `grade_eng`     decimal(3,2) NOT NULL DEFAULT '0.00',
  `grade_thai`    decimal(3,2) NOT NULL DEFAULT '0.00',
  `grade_social`  decimal(3,2) NOT NULL DEFAULT '0.00',
  `grade_art`     decimal(3,2) NOT NULL DEFAULT '0.00',
  `avg_grade`     decimal(4,2) DEFAULT NULL,
  `mbti_type`     varchar(4)   NOT NULL,
  `mbti_e_i`      char(1)      NOT NULL,
  `mbti_s_n`      char(1)      NOT NULL,
  `mbti_t_f`      char(1)      NOT NULL,
  `mbti_j_p`      char(1)      NOT NULL,
  `mbti_detail`   json,
  `answers_total` int(11)      DEFAULT NULL,
  `branch_id`     int(11)      DEFAULT NULL,
  `branch_name`   varchar(100) DEFAULT NULL,
  `score`         decimal(5,2) DEFAULT NULL,
  `created_at`    timestamp    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `user_id` (`user_id`),
  CONSTRAINT `fk_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ---- 4) คำถามแบบทดสอบ MBTI ----
-- โครงสร้างตรงกับที่ decision_tree.py / get_questions.php ใช้:
--   category = EI / SN / TF / JP, ตัวเลือก A/B แต่ละข้อระบุ trait ตัวอักษรเดียว
CREATE TABLE IF NOT EXISTS `mbti_questions` (
  `id`             int(11) NOT NULL AUTO_INCREMENT,
  `category`       char(2) NOT NULL COMMENT 'EI / SN / TF / JP',
  `question_no`    int(11) NOT NULL,
  `question_text`  text    NOT NULL,
  `option_a_text`  text    NOT NULL,
  `option_a_trait` char(1) NOT NULL,
  `option_b_text`  text    NOT NULL,
  `option_b_trait` char(1) NOT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_category_no` (`category`, `question_no`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ชุดคำถามมาตรฐาน 20 ข้อ (มิติละ 5 ข้อ)
INSERT IGNORE INTO `mbti_questions`
  (`id`, `category`, `question_no`, `question_text`, `option_a_text`, `option_a_trait`, `option_b_text`, `option_b_trait`)
VALUES
-- EI: พลังงาน (Extrovert / Introvert)
(1,  'EI', 1, 'เวลาไปงานเลี้ยงหรือกิจกรรมที่มีคนเยอะๆ คุณรู้สึกอย่างไร?',
     'สนุกและได้พลังงาน อยากพูดคุยกับหลายๆ คน', 'E',
     'เหนื่อยง่าย อยากกลับไปพักเงียบๆ คนเดียว', 'I'),
(2,  'EI', 2, 'เวลามีเรื่องไม่สบายใจ คุณมักจะทำอย่างไร?',
     'เล่าให้เพื่อนหรือคนใกล้ตัวฟัง เพื่อช่วยกันคิด', 'E',
     'เก็บมาคิดทบทวนเงียบๆ คนเดียวก่อน', 'I'),
(3,  'EI', 3, 'วันหยุดในฝันของคุณเป็นแบบไหน?',
     'ออกไปเที่ยวข้างนอกกับกลุ่มเพื่อน', 'E',
     'อยู่บ้านอ่านหนังสือ ดูหนัง หรือทำงานอดิเรกเงียบๆ', 'I'),
(4,  'EI', 4, 'ในห้องเรียนหรือที่ประชุม คุณเป็นคนแบบไหน?',
     'ชอบยกมือตอบและแสดงความคิดเห็น', 'E',
     'ชอบฟังและจดบันทึกมากกว่าพูด', 'I'),
(5,  'EI', 5, 'เวลาเจอคนแปลกหน้าหรือเพื่อนใหม่ คุณมักจะ...',
     'เข้าไปทักทายก่อนได้อย่างสบายใจ', 'E',
     'รอให้อีกฝ่ายเข้ามาทักก่อน', 'I'),
-- SN: การรับข้อมูล (Sensing / Intuition)
(6,  'SN', 1, 'เวลาเรียนรู้สิ่งใหม่ คุณชอบแบบไหนมากกว่า?',
     'มีตัวอย่างจริงและขั้นตอนที่ชัดเจนให้ทำตาม', 'S',
     'เข้าใจแนวคิดภาพรวม แล้วต่อยอดจินตนาการเอง', 'N'),
(7,  'SN', 2, 'คุณเชื่อถือสิ่งไหนมากกว่ากัน?',
     'ประสบการณ์ตรงและข้อเท็จจริงที่พิสูจน์ได้', 'S',
     'ลางสังหรณ์และความเป็นไปได้ใหม่ๆ', 'N'),
(8,  'SN', 3, 'หนังสือหรือภาพยนตร์แบบไหนถูกใจคุณ?',
     'เรื่องราวสมจริง อิงชีวิตจริงหรือประวัติศาสตร์', 'S',
     'แนวแฟนตาซี ไซไฟ หรือโลกในจินตนาการ', 'N'),
(9,  'SN', 4, 'เวลาทำงานหรือทำการบ้าน คุณมักจะ...',
     'ใช้วิธีที่เคยได้ผลมาแล้ว มั่นใจกว่า', 'S',
     'ลองคิดหาวิธีใหม่ๆ ของตัวเอง แม้จะเสี่ยง', 'N'),
(10, 'SN', 5, 'คุณสนใจเรื่องไหนมากกว่ากัน?',
     'สิ่งที่กำลังเกิดขึ้นจริงในปัจจุบัน', 'S',
     'สิ่งที่อาจจะเกิดขึ้นได้ในอนาคต', 'N'),
-- TF: การตัดสินใจ (Thinking / Feeling)
(11, 'TF', 1, 'เวลาต้องตัดสินใจเรื่องสำคัญ คุณใช้อะไรนำ?',
     'เหตุผล ข้อมูล และข้อดีข้อเสีย', 'T',
     'ความรู้สึกของตัวเองและผลกระทบต่อคนรอบข้าง', 'F'),
(12, 'TF', 2, 'เมื่อเพื่อนมาปรึกษาปัญหา คุณมักจะ...',
     'ช่วยวิเคราะห์สาเหตุและหาทางแก้ให้', 'T',
     'รับฟังและปลอบใจให้เขารู้สึกดีขึ้นก่อน', 'F'),
(13, 'TF', 3, 'คำชมแบบไหนทำให้คุณดีใจกว่ากัน?',
     '"คุณเก่งมาก ทำงานได้แม่นยำและมีประสิทธิภาพ"', 'T',
     '"คุณใจดีมาก อยู่ด้วยแล้วรู้สึกอบอุ่น"', 'F'),
(14, 'TF', 4, 'เวลาต้องติชมงานของคนอื่น คุณมักจะ...',
     'พูดตรงไปตรงมาตามความเป็นจริง', 'T',
     'เลือกคำพูดอย่างระวังเพื่อถนอมน้ำใจ', 'F'),
(15, 'TF', 5, 'สำหรับคุณ ความยุติธรรมคืออะไร?',
     'ทุกคนถูกตัดสินด้วยกติกาเดียวกันอย่างเท่าเทียม', 'T',
     'พิจารณาเป็นรายกรณี โดยคำนึงถึงความเห็นอกเห็นใจ', 'F'),
-- JP: การใช้ชีวิต (Judging / Perceiving)
(16, 'JP', 1, 'ก่อนออกเดินทางไปเที่ยว คุณเป็นแบบไหน?',
     'วางแผนละเอียดล่วงหน้า จองทุกอย่างให้เรียบร้อย', 'J',
     'ไปแบบชิลๆ ค่อยตัดสินใจเอาหน้างาน', 'P'),
(17, 'JP', 2, 'กับงานที่มีกำหนดส่ง คุณมักจะ...',
     'รีบทำให้เสร็จก่อนกำหนดนานๆ จะได้สบายใจ', 'J',
     'ทำใกล้ๆ เดดไลน์ แล้วค่อยเร่งตอนท้าย', 'P'),
(18, 'JP', 3, 'โต๊ะเรียนหรือห้องของคุณเป็นแบบไหน?',
     'จัดระเบียบเรียบร้อย ทุกอย่างมีที่ของมัน', 'J',
     'วางของตามสะดวก เดี๋ยวก็หาเจอเอง', 'P'),
(19, 'JP', 4, 'ถ้าแผนที่วางไว้ถูกเปลี่ยนกะทันหัน คุณรู้สึกอย่างไร?',
     'หงุดหงิด อยากให้ทุกอย่างเป็นไปตามแผนเดิม', 'J',
     'ไม่เป็นไร ถือว่าได้ลองอะไรใหม่ๆ', 'P'),
(20, 'JP', 5, 'คุณชอบใช้ชีวิตแบบไหนมากกว่า?',
     'มีตารางเวลาชัดเจน รู้ล่วงหน้าว่าต้องทำอะไร', 'J',
     'ยืดหยุ่นอิสระ ปรับเปลี่ยนตามสถานการณ์', 'P');
