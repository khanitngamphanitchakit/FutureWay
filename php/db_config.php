<?php
// ========================================
// FutureWay - db_config.php
// ไฟล์เดียวสำหรับตั้งค่าและเชื่อมต่อ Database
// ให้ทุกไฟล์ require ตัวนี้แทนการ hardcode ค่าเชื่อมต่อซ้ำๆ
// ========================================

// อ่านจาก environment variable (Railway จะ inject ให้อัตโนมัติ
// เมื่อผูกตัวแปร MYSQL* ของ service MySQL เข้ากับ service แอปนี้)
define('DB_HOST', getenv('MYSQLHOST') ?: 'mysql.railway.internal');
define('DB_USER', getenv('MYSQLUSER') ?: 'root');
define('DB_PASS', getenv('MYSQLPASSWORD') ?: '');
define('DB_NAME', getenv('MYSQLDATABASE') ?: 'railway');
define('DB_PORT', (int)(getenv('MYSQLPORT') ?: 3306));

/**
 * เปิดการเชื่อมต่อ Database ใหม่ 1 connection
 * ใช้ mysqli_report(MYSQLI_REPORT_OFF) เพื่อไม่ให้ throw exception ตอน connect ไม่ได้
 * (ให้ตรวจสอบ $conn->connect_error เองแทน เหมือนที่ไฟล์เดิมทำอยู่)
 *
 * @return mysqli
 * @throws Exception ถ้าเชื่อมต่อไม่สำเร็จ
 */
function getDbConnection(): mysqli {
    mysqli_report(MYSQLI_REPORT_OFF);

    $conn = new mysqli(DB_HOST, DB_USER, DB_PASS, DB_NAME, DB_PORT);

    if ($conn->connect_error) {
        throw new Exception('DB connection failed: ' . $conn->connect_error);
    }

    $conn->set_charset('utf8mb4');
    return $conn;
}
