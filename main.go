package main

import (
	"database/sql"
	"fmt"
	"log"
	"net/http"
	"net/url"
	"os"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/joho/godotenv"
	_ "github.com/lib/pq"
)

var (
	dbPrimary *sql.DB
	dbReplica *sql.DB
)

// getEnv trả về giá trị biến môi trường, nếu rỗng thì dùng giá trị mặc định
func getEnv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}

// buildDSN dựng chuỗi kết nối từ biến môi trường, tự escape password có ký tự đặc biệt
func buildDSN(port string) string {
	u := url.URL{
		Scheme:   "postgres",
		User:     url.UserPassword(os.Getenv("POSTGRES_USER"), os.Getenv("POSTGRES_PASSWORD")),
		Host:     fmt.Sprintf("%s:%s", getEnv("DB_HOST", "localhost"), port),
		Path:     getEnv("DB_NAME", "shop_db"),
		RawQuery: "sslmode=disable",
	}
	return u.String()
}

// openDB mở pool và Ping để phát hiện lỗi kết nối ngay khi khởi động
func openDB(dsn string) (*sql.DB, error) {
	db, err := sql.Open("postgres", dsn)
	if err != nil {
		return nil, err
	}
	db.SetMaxOpenConns(25)
	db.SetMaxIdleConns(10)
	if err := db.Ping(); err != nil {
		return nil, err
	}
	return db, nil
}

func main() {
	var err error

	// Đọc file .env cùng cấp (nếu không có thì dùng biến môi trường hệ thống)
	if err := godotenv.Load(); err != nil {
		log.Println("Không tìm thấy file .env, dùng biến môi trường hệ thống")
	}

	// Kiểm tra các biến bắt buộc
	for _, key := range []string{"POSTGRES_USER", "POSTGRES_PASSWORD"} {
		if os.Getenv(key) == "" {
			log.Fatalf("Thiếu biến môi trường bắt buộc: %s", key)
		}
	}

	// 1. Kết nối Pool Ghi/Đọc vào pg-primary (mặc định cổng 5432)
	dbPrimary, err = openDB(buildDSN(getEnv("DB_PRIMARY_PORT", "5432")))
	if err != nil {
		log.Fatal("Lỗi kết nối Primary:", err)
	}

	// 2. Kết nối Pool Chỉ Đọc (Read Replica) vào pg-replica (mặc định cổng 5433)
	dbReplica, err = openDB(buildDSN(getEnv("DB_REPLICA_PORT", "5433")))
	if err != nil {
		log.Fatal("Lỗi kết nối Replica:", err)
	}

	// Khởi tạo bảng demo_orders trên Primary nếu chưa tồn tại
	_, err = dbPrimary.Exec(`
		CREATE TABLE IF NOT EXISTS demo_orders (
			id SERIAL PRIMARY KEY,
			customer_name TEXT NOT NULL,
			amount INT NOT NULL,
			created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
		);
	`)
	if err != nil {
		log.Printf("Cảnh báo khởi tạo bảng: %v\n", err)
	}

	r := gin.Default()

	// API 1: Bơm tải ghi liên tục vào Primary (POST /api/orders/seed)
	r.POST("/api/orders/seed", func(c *gin.Context) {
		start := time.Now()
		totalInsert := 5000

		tx, err := dbPrimary.Begin()
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}

		stmt, err := tx.Prepare("INSERT INTO demo_orders (customer_name, amount) VALUES ($1, $2)")
		if err != nil {
			tx.Rollback()
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}
		defer stmt.Close()

		for i := 1; i <= totalInsert; i++ {
			_, err := stmt.Exec(fmt.Sprintf("Khach_Hang_%d", i), i*100)
			if err != nil {
				tx.Rollback()
				c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
				return
			}
		}

		if err := tx.Commit(); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}

		c.JSON(http.StatusOK, gin.H{
			"message":       "Ghi tải dữ liệu vào pg-primary (Port 5432) thành công!",
			"inserted_rows": totalInsert,
			"duration_ms":   time.Since(start).Milliseconds(),
		})
	})

	// API 2: Đo độ trễ Replication Lag trên Primary & Đọc dữ liệu từ Replica
	// (GET /api/replication/status)
	r.GET("/api/replication/status", func(c *gin.Context) {
		var clientAddr, state, syncState string
		var lagBytes int64

		err := dbPrimary.QueryRow(`
			SELECT
				COALESCE(client_addr::text, 'N/A'),
				state,
				sync_state,
				pg_wal_lsn_diff(pg_current_wal_lsn(), replay_lsn) AS lag_bytes
			FROM pg_stat_replication
			LIMIT 1;
		`).Scan(&clientAddr, &state, &syncState, &lagBytes)

		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Không đọc được pg_stat_replication: " + err.Error()})
			return
		}

		var primaryCount, replicaCount int64
		_ = dbPrimary.QueryRow("SELECT COUNT(*) FROM demo_orders;").Scan(&primaryCount)
		_ = dbReplica.QueryRow("SELECT COUNT(*) FROM demo_orders;").Scan(&replicaCount)

		c.JSON(http.StatusOK, gin.H{
			"replication_state":     state,
			"sync_mode":             syncState,
			"replica_ip":            clientAddr,
			"replication_lag_bytes": lagBytes,
			"primary_total_records": primaryCount,
			"replica_total_records": replicaCount,
			"is_fully_synchronized": primaryCount == replicaCount && lagBytes == 0,
		})
	})

	log.Println("Golang Gin Backend đang chạy tại http://localhost:8080")
	r.Run(":8080")
}
