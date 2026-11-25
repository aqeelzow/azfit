import GRDB

/// The tables. One `v1` migration until the first TestFlight, then additive migrations only (D-005).
enum Schema {
    /// Every synced table: each has a text `id` primary key.
    static let tables = [
        "profile", "nutrition_target", "planned_session", "planned_exercise", "workout", "logged_set", "meal", "food_day",
        "weigh_in", "body_measurement", "div_change", "memory", "week_review",
    ]

    static var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("v1") { db in
            try db.execute(
                sql: """
                    CREATE TABLE profile (
                        id TEXT PRIMARY KEY NOT NULL,
                        name TEXT,
                        sex TEXT,
                        birth_year INTEGER,
                        height_cm REAL,
                        goal TEXT NOT NULL,
                        training_days INTEGER NOT NULL,
                        units TEXT NOT NULL,
                        kidney_disease INTEGER NOT NULL,
                        tracks_cycle INTEGER NOT NULL,
                        target_rate_pct_per_week REAL NOT NULL,
                        autonomy TEXT NOT NULL,
                        created_at TEXT NOT NULL
                    );
                    CREATE TABLE nutrition_target (
                        id TEXT PRIMARY KEY NOT NULL,
                        start_day TEXT NOT NULL,
                        kcal INTEGER NOT NULL,
                        protein_g_per_kg REAL NOT NULL,
                        source TEXT NOT NULL,
                        div_change_id TEXT
                    );
                    CREATE TABLE planned_session (
                        id TEXT PRIMARY KEY NOT NULL,
                        name TEXT NOT NULL,
                        weekday INTEGER NOT NULL,
                        position INTEGER NOT NULL,
                        moved_to_weekday INTEGER,
                        moved_until_day TEXT
                    );
                    CREATE TABLE planned_exercise (
                        id TEXT PRIMARY KEY NOT NULL,
                        session_id TEXT NOT NULL,
                        exercise_id TEXT NOT NULL,
                        position INTEGER NOT NULL,
                        sets INTEGER NOT NULL,
                        rep_min INTEGER NOT NULL,
                        rep_max INTEGER NOT NULL,
                        load_kg REAL,
                        hit_top_of_range_sessions INTEGER NOT NULL,
                        swapped_from_id TEXT,
                        swap_ends_day TEXT
                    );
                    CREATE INDEX planned_exercise_session ON planned_exercise(session_id);
                    CREATE TABLE workout (
                        id TEXT PRIMARY KEY NOT NULL,
                        planned_session_id TEXT,
                        name TEXT NOT NULL,
                        day TEXT NOT NULL,
                        started_at TEXT NOT NULL,
                        ended_at TEXT,
                        skipped INTEGER NOT NULL
                    );
                    CREATE INDEX workout_day ON workout(day);
                    CREATE TABLE logged_set (
                        id TEXT PRIMARY KEY NOT NULL,
                        workout_id TEXT NOT NULL,
                        exercise_id TEXT NOT NULL,
                        position INTEGER NOT NULL,
                        load_kg REAL NOT NULL,
                        reps INTEGER NOT NULL,
                        rir REAL,
                        at TEXT NOT NULL
                    );
                    CREATE INDEX logged_set_workout ON logged_set(workout_id);
                    CREATE INDEX logged_set_exercise ON logged_set(exercise_id);
                    CREATE TABLE meal (
                        id TEXT PRIMARY KEY NOT NULL,
                        day TEXT NOT NULL,
                        at TEXT NOT NULL,
                        name TEXT NOT NULL,
                        kcal REAL NOT NULL,
                        kcal_low REAL,
                        kcal_high REAL,
                        protein_g REAL NOT NULL,
                        carbs_g REAL NOT NULL,
                        fat_g REAL NOT NULL,
                        source TEXT NOT NULL,
                        barcode TEXT,
                        is_favorite INTEGER NOT NULL,
                        removed INTEGER NOT NULL
                    );
                    CREATE INDEX meal_day ON meal(day);
                    CREATE TABLE food_day (
                        id TEXT PRIMARY KEY NOT NULL,
                        complete INTEGER
                    );
                    CREATE TABLE weigh_in (
                        id TEXT PRIMARY KEY NOT NULL,
                        day TEXT NOT NULL,
                        at TEXT NOT NULL,
                        kg REAL NOT NULL,
                        source TEXT NOT NULL
                    );
                    CREATE INDEX weigh_in_day ON weigh_in(day);
                    CREATE TABLE body_measurement (
                        id TEXT PRIMARY KEY NOT NULL,
                        day TEXT NOT NULL,
                        site TEXT NOT NULL,
                        cm REAL NOT NULL,
                        source TEXT NOT NULL
                    );
                    CREATE TABLE div_change (
                        id TEXT PRIMARY KEY NOT NULL,
                        created_at TEXT NOT NULL,
                        job TEXT NOT NULL,
                        proposal TEXT NOT NULL,
                        status TEXT NOT NULL,
                        notes TEXT NOT NULL,
                        resolved_at TEXT,
                        undo TEXT
                    );
                    CREATE TABLE memory (
                        id TEXT PRIMARY KEY NOT NULL,
                        text TEXT NOT NULL,
                        source TEXT NOT NULL,
                        created_at TEXT NOT NULL
                    );

                    -- Sync (D-006): every local write is logged with a rising sequence. Rows that arrive from the other
                    -- side are written with sync_state.applying = 1, so they aren't logged and sent back.
                    CREATE TABLE sync_log (
                        seq INTEGER PRIMARY KEY AUTOINCREMENT,
                        table_name TEXT NOT NULL,
                        row_id TEXT NOT NULL,
                        deleted INTEGER NOT NULL
                    );
                    CREATE TABLE sync_state (
                        id INTEGER PRIMARY KEY CHECK (id = 1),
                        applying INTEGER NOT NULL
                    );
                    INSERT INTO sync_state (id, applying) VALUES (1, 0);
                    -- For each peer (a bridge or a phone): the last of its sequences we received, and the last of ours
                    -- it confirmed.
                    CREATE TABLE sync_peer (
                        peer_id TEXT PRIMARY KEY NOT NULL,
                        received_seq INTEGER NOT NULL,
                        acknowledged_seq INTEGER NOT NULL
                    );
                    """)
            for table in tables where table != "week_review" { try logChanges(to: table, db) }
        }
        // Additive from here on: databases already made with v1 exist on phones and bridges.
        migrator.registerMigration("v2 workout note") { db in
            try db.execute(sql: "ALTER TABLE workout ADD COLUMN div_note TEXT")
        }
        migrator.registerMigration("v3 week review") { db in
            try db.execute(
                sql: """
                    CREATE TABLE week_review (
                        id TEXT PRIMARY KEY NOT NULL,
                        week_ending TEXT NOT NULL,
                        summary TEXT NOT NULL,
                        calorie_reasoning TEXT NOT NULL,
                        questions TEXT NOT NULL,
                        created_at TEXT NOT NULL
                    );
                    CREATE INDEX week_review_week ON week_review(week_ending);
                    """)
            try logChanges(to: "week_review", db)
        }
        return migrator
    }

    /// Triggers that put every write to `table` in `sync_log`, except while applying the other side's rows.
    static func logChanges(to table: String, _ db: Database) throws {
        let notApplying = "WHEN (SELECT applying FROM sync_state) = 0"
        try db.execute(
            sql: """
                CREATE TRIGGER \(table)_sync_insert AFTER INSERT ON \(table) \(notApplying)
                BEGIN INSERT INTO sync_log (table_name, row_id, deleted) VALUES ('\(table)', NEW.id, 0); END;
                CREATE TRIGGER \(table)_sync_update AFTER UPDATE ON \(table) \(notApplying)
                BEGIN INSERT INTO sync_log (table_name, row_id, deleted) VALUES ('\(table)', NEW.id, 0); END;
                CREATE TRIGGER \(table)_sync_delete AFTER DELETE ON \(table) \(notApplying)
                BEGIN INSERT INTO sync_log (table_name, row_id, deleted) VALUES ('\(table)', OLD.id, 1); END;
                """)
    }
}
