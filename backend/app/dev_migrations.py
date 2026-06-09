from sqlalchemy import inspect, text
from sqlalchemy.engine import Engine


def ensure_sqlite_schema(engine: Engine) -> None:
    if not engine.url.drivername.startswith("sqlite"):
        return

    inspector = inspect(engine)
    table_names = inspector.get_table_names()

    event_columns = (
        {column["name"] for column in inspector.get_columns("events")}
        if "events" in table_names
        else set()
    )
    event_additions = {
        "quiz_id": "INTEGER",
        "is_daily_challenge": "BOOLEAN NOT NULL DEFAULT 0",
        "start_date": "DATETIME",
        "end_date": "DATETIME",
    }

    with engine.begin() as connection:
        if "users" in table_names:
            user_columns = {
                column["name"]
                for column in inspector.get_columns("users")
            }
            user_additions = {
                "date_of_birth": "DATE",
                "reset_token": "VARCHAR",
                "reset_token_expires": "DATETIME",
                "roles": "TEXT",
            }
            for column, ddl_type in user_additions.items():
                if column not in user_columns:
                    connection.execute(
                        text(f"ALTER TABLE users ADD COLUMN {column} {ddl_type}")
                    )

        if "student_reminders" not in table_names:
            connection.execute(text("""
                CREATE TABLE student_reminders (
                    id INTEGER NOT NULL,
                    user_id INTEGER NOT NULL,
                    title VARCHAR NOT NULL,
                    scheduled_at DATETIME NOT NULL,
                    is_done BOOLEAN NOT NULL DEFAULT 0,
                    is_active BOOLEAN NOT NULL DEFAULT 1,
                    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                    PRIMARY KEY (id),
                    FOREIGN KEY(user_id) REFERENCES users (id)
                )
            """))
            connection.execute(text("CREATE INDEX ix_student_reminders_id ON student_reminders (id)"))
            connection.execute(text("CREATE INDEX ix_student_reminders_user_id ON student_reminders (user_id)"))

        if "events" in table_names:
            for column, ddl_type in event_additions.items():
                if column not in event_columns:
                    connection.execute(
                        text(f"ALTER TABLE events ADD COLUMN {column} {ddl_type}")
                    )

        if "event_participants" in inspector.get_table_names():
            participant_columns = {
                column["name"]
                for column in inspector.get_columns("event_participants")
            }
            if "slot_id" not in participant_columns:
                connection.execute(
                    text("ALTER TABLE event_participants ADD COLUMN slot_id INTEGER")
                )

        if "event_slots" not in inspector.get_table_names():
            connection.execute(text("""
                CREATE TABLE event_slots (
                    id INTEGER NOT NULL,
                    event_id INTEGER NOT NULL,
                    title VARCHAR NOT NULL,
                    starts_at DATETIME NOT NULL,
                    ends_at DATETIME,
                    capacity INTEGER NOT NULL DEFAULT 1,
                    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                    PRIMARY KEY (id),
                    FOREIGN KEY(event_id) REFERENCES events (id)
                )
            """))
            connection.execute(
                text("CREATE INDEX ix_event_slots_id ON event_slots (id)")
            )

        if "lessons" not in inspector.get_table_names():
            connection.execute(text("""
                CREATE TABLE lessons (
                    id INTEGER NOT NULL,
                    course_id INTEGER NOT NULL,
                    title VARCHAR NOT NULL,
                    description VARCHAR,
                    content_type VARCHAR NOT NULL DEFAULT 'text',
                    content_url VARCHAR,
                    content_text TEXT,
                    "order" INTEGER NOT NULL DEFAULT 0,
                    duration_minutes INTEGER,
                    is_published BOOLEAN NOT NULL DEFAULT 1,
                    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                    PRIMARY KEY (id),
                    FOREIGN KEY(course_id) REFERENCES courses (id)
                )
            """))
            connection.execute(text("CREATE INDEX ix_lessons_id ON lessons (id)"))
            connection.execute(text("CREATE INDEX ix_lessons_course_id ON lessons (course_id)"))

        if "user_lesson_progress" not in inspector.get_table_names():
            connection.execute(text("""
                CREATE TABLE user_lesson_progress (
                    id INTEGER NOT NULL,
                    user_id INTEGER NOT NULL,
                    lesson_id INTEGER NOT NULL,
                    completed BOOLEAN NOT NULL DEFAULT 0,
                    completed_at DATETIME,
                    PRIMARY KEY (id),
                    FOREIGN KEY(user_id) REFERENCES users (id),
                    FOREIGN KEY(lesson_id) REFERENCES lessons (id)
                )
            """))
            connection.execute(text("CREATE INDEX ix_user_lesson_progress_id ON user_lesson_progress (id)"))

        if "safety_awareness_questions" not in inspector.get_table_names():
            connection.execute(text("""
                CREATE TABLE safety_awareness_questions (
                    id INTEGER NOT NULL,
                    question_text VARCHAR NOT NULL,
                    option_a VARCHAR NOT NULL,
                    option_b VARCHAR NOT NULL,
                    option_c VARCHAR NOT NULL,
                    correct_option VARCHAR NOT NULL,
                    explanation VARCHAR NOT NULL,
                    category VARCHAR NOT NULL DEFAULT 'general',
                    is_active BOOLEAN NOT NULL DEFAULT 1,
                    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                    PRIMARY KEY (id)
                )
            """))
            connection.execute(text("CREATE INDEX ix_safety_awareness_questions_id ON safety_awareness_questions (id)"))

        if "user_safety_answers" not in inspector.get_table_names():
            connection.execute(text("""
                CREATE TABLE user_safety_answers (
                    id INTEGER NOT NULL,
                    user_id INTEGER NOT NULL,
                    question_id INTEGER NOT NULL,
                    chosen_option VARCHAR NOT NULL,
                    is_correct BOOLEAN NOT NULL,
                    answered_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                    PRIMARY KEY (id),
                    FOREIGN KEY(user_id) REFERENCES users (id),
                    FOREIGN KEY(question_id) REFERENCES safety_awareness_questions (id)
                )
            """))
            connection.execute(text("CREATE INDEX ix_user_safety_answers_id ON user_safety_answers (id)"))

        if "courses" in inspector.get_table_names():
            course_columns = {col["name"] for col in inspector.get_columns("courses")}
            course_additions = {
                "learn_items": "TEXT",
                "skill_tags": "TEXT",
                "course_description": "TEXT",
                "offer_price": "INTEGER",
                "original_price": "INTEGER",
                "offer_label": "VARCHAR",
            }
            for column, ddl_type in course_additions.items():
                if column not in course_columns:
                    connection.execute(
                        text(f"ALTER TABLE courses ADD COLUMN {column} {ddl_type}")
                    )

        if "counselling_sessions" in inspector.get_table_names():
            counselling_columns = {
                column["name"]
                for column in inspector.get_columns("counselling_sessions")
            }
            counselling_additions = {
                "slot_id": "INTEGER",
                "mentor_id": "INTEGER",
                "ends_at": "DATETIME",
                "meeting_url": "VARCHAR",
            }
            for column, ddl_type in counselling_additions.items():
                if column not in counselling_columns:
                    connection.execute(
                        text(f"ALTER TABLE counselling_sessions ADD COLUMN {column} {ddl_type}")
                    )

        if "counselling_availability" not in inspector.get_table_names():
            connection.execute(text("""
                CREATE TABLE counselling_availability (
                    id INTEGER NOT NULL,
                    mentor_id INTEGER NOT NULL,
                    mentor_name VARCHAR NOT NULL,
                    starts_at DATETIME NOT NULL,
                    ends_at DATETIME NOT NULL,
                    topic VARCHAR,
                    capacity INTEGER NOT NULL DEFAULT 1,
                    booked_count INTEGER NOT NULL DEFAULT 0,
                    meeting_url VARCHAR,
                    is_active BOOLEAN NOT NULL DEFAULT 1,
                    slot_duration_minutes INTEGER NOT NULL DEFAULT 45,
                    recurrence_type VARCHAR NOT NULL DEFAULT 'none',
                    recurrence_end_date DATETIME,
                    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                    PRIMARY KEY (id),
                    FOREIGN KEY(mentor_id) REFERENCES users (id)
                )
            """))
            connection.execute(text("CREATE INDEX ix_counselling_availability_id ON counselling_availability (id)"))
        else:
            # Add new columns to existing counselling_availability table
            avail_columns = {col["name"] for col in inspector.get_columns("counselling_availability")}
            avail_additions = {
                "slot_duration_minutes": "INTEGER NOT NULL DEFAULT 45",
                "recurrence_type": "VARCHAR NOT NULL DEFAULT 'none'",
                "recurrence_end_date": "DATETIME",
            }
            for column, ddl_type in avail_additions.items():
                if column not in avail_columns:
                    connection.execute(
                        text(f"ALTER TABLE counselling_availability ADD COLUMN {column} {ddl_type}")
                    )

        # mentor_profiles table
        if "mentor_profiles" not in inspector.get_table_names():
            connection.execute(text("""
                CREATE TABLE mentor_profiles (
                    id INTEGER NOT NULL,
                    user_id INTEGER NOT NULL UNIQUE,
                    display_name VARCHAR NOT NULL,
                    bio TEXT,
                    expertise VARCHAR,
                    category VARCHAR,
                    profile_image_url VARCHAR,
                    is_active BOOLEAN NOT NULL DEFAULT 1,
                    rating REAL NOT NULL DEFAULT 0.0,
                    session_count INTEGER NOT NULL DEFAULT 0,
                    google_calendar_id VARCHAR,
                    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                    PRIMARY KEY (id),
                    FOREIGN KEY(user_id) REFERENCES users (id)
                )
            """))
            connection.execute(text("CREATE INDEX ix_mentor_profiles_id ON mentor_profiles (id)"))
            connection.execute(text("CREATE UNIQUE INDEX ix_mentor_profiles_user_id ON mentor_profiles (user_id)"))

        # ── comment moderation columns ────────────────────────────────────────
        if "comments" in inspector.get_table_names():
            comment_cols = {col["name"] for col in inspector.get_columns("comments")}
            comment_additions = {
                "flag_count":    "INTEGER NOT NULL DEFAULT 0",
                "is_flagged":    "BOOLEAN NOT NULL DEFAULT 0",
                "is_hidden":     "BOOLEAN NOT NULL DEFAULT 0",
                "hidden_by":     "INTEGER",
                "hidden_reason": "TEXT",
            }
            for column, ddl_type in comment_additions.items():
                if column not in comment_cols:
                    connection.execute(
                        text(f"ALTER TABLE comments ADD COLUMN {column} {ddl_type}")
                    )

        # ── creator_post maker-checker columns ────────────────────────────────
        if "creator_posts" in inspector.get_table_names():
            post_cols = {col["name"] for col in inspector.get_columns("creator_posts")}
            post_additions = {
                "approved_by":      "INTEGER",
                "approved_at":      "DATETIME",
                "rejection_reason": "VARCHAR",
            }
            for column, ddl_type in post_additions.items():
                if column not in post_cols:
                    connection.execute(
                        text(f"ALTER TABLE creator_posts ADD COLUMN {column} {ddl_type}")
                    )

        # ── event maker-checker columns ───────────────────────────────────────
        if "events" in inspector.get_table_names():
            ev_cols = {col["name"] for col in inspector.get_columns("events")}
            ev_additions = {
                "approved_by":      "INTEGER",
                "approved_at":      "DATETIME",
                "rejection_reason": "VARCHAR",
            }
            for column, ddl_type in ev_additions.items():
                if column not in ev_cols:
                    connection.execute(
                        text(f"ALTER TABLE events ADD COLUMN {column} {ddl_type}")
                    )

        # counselling_notifications table
        if "counselling_notifications" not in inspector.get_table_names():
            connection.execute(text("""
                CREATE TABLE counselling_notifications (
                    id INTEGER NOT NULL,
                    user_id INTEGER NOT NULL,
                    type VARCHAR NOT NULL,
                    message TEXT NOT NULL,
                    booking_ref VARCHAR,
                    is_read BOOLEAN NOT NULL DEFAULT 0,
                    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                    PRIMARY KEY (id),
                    FOREIGN KEY(user_id) REFERENCES users (id)
                )
            """))
            connection.execute(text("CREATE INDEX ix_counselling_notifications_id ON counselling_notifications (id)"))

        if "reward_transactions" not in inspector.get_table_names():
            connection.execute(text("""
                CREATE TABLE reward_transactions (
                    id INTEGER NOT NULL,
                    user_id INTEGER NOT NULL,
                    actor_id INTEGER,
                    points INTEGER NOT NULL,
                    xp INTEGER NOT NULL DEFAULT 0,
                    trigger VARCHAR NOT NULL,
                    title VARCHAR NOT NULL,
                    message TEXT,
                    source_type VARCHAR,
                    source_id INTEGER,
                    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                    PRIMARY KEY (id),
                    FOREIGN KEY(user_id) REFERENCES users (id),
                    FOREIGN KEY(actor_id) REFERENCES users (id)
                )
            """))
            connection.execute(text("CREATE INDEX ix_reward_transactions_id ON reward_transactions (id)"))
            connection.execute(text("CREATE INDEX ix_reward_transactions_user_id ON reward_transactions (user_id)"))

        if "reward_rules" not in inspector.get_table_names():
            connection.execute(text("""
                CREATE TABLE reward_rules (
                    id INTEGER NOT NULL,
                    role VARCHAR NOT NULL DEFAULT 'student',
                    trigger VARCHAR NOT NULL,
                    points INTEGER NOT NULL DEFAULT 0,
                    xp INTEGER NOT NULL DEFAULT 0,
                    title VARCHAR NOT NULL,
                    description TEXT,
                    is_active BOOLEAN NOT NULL DEFAULT 1,
                    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                    PRIMARY KEY (id)
                )
            """))
            connection.execute(text("CREATE INDEX ix_reward_rules_id ON reward_rules (id)"))

        if "reward_tasks" not in inspector.get_table_names():
            connection.execute(text("""
                CREATE TABLE reward_tasks (
                    id INTEGER NOT NULL,
                    user_id INTEGER NOT NULL,
                    created_by INTEGER,
                    title VARCHAR NOT NULL,
                    description TEXT,
                    target_count INTEGER NOT NULL DEFAULT 1,
                    current_count INTEGER NOT NULL DEFAULT 0,
                    reward_points INTEGER NOT NULL DEFAULT 0,
                    reward_xp INTEGER NOT NULL DEFAULT 0,
                    status VARCHAR NOT NULL DEFAULT 'active',
                    due_at DATETIME,
                    completed_at DATETIME,
                    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                    PRIMARY KEY (id),
                    FOREIGN KEY(user_id) REFERENCES users (id),
                    FOREIGN KEY(created_by) REFERENCES users (id)
                )
            """))
            connection.execute(text("CREATE INDEX ix_reward_tasks_id ON reward_tasks (id)"))
            connection.execute(text("CREATE INDEX ix_reward_tasks_user_id ON reward_tasks (user_id)"))

        if "user_streaks" not in inspector.get_table_names():
            connection.execute(text("""
                CREATE TABLE user_streaks (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    user_id INTEGER NOT NULL UNIQUE,
                    current_streak INTEGER NOT NULL DEFAULT 1,
                    longest_streak INTEGER NOT NULL DEFAULT 1,
                    last_activity_date DATE,
                    total_active_days INTEGER NOT NULL DEFAULT 1,
                    FOREIGN KEY(user_id) REFERENCES users (id)
                )
            """))
            connection.execute(text("CREATE INDEX ix_user_streaks_id ON user_streaks (id)"))
            connection.execute(text("CREATE UNIQUE INDEX ix_user_streaks_user_id ON user_streaks (user_id)"))

        if "user_milestones" not in inspector.get_table_names():
            connection.execute(text("""
                CREATE TABLE user_milestones (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    user_id INTEGER NOT NULL,
                    milestone_key VARCHAR NOT NULL,
                    title VARCHAR NOT NULL,
                    description TEXT,
                    points INTEGER NOT NULL DEFAULT 0,
                    xp INTEGER NOT NULL DEFAULT 0,
                    achieved_at DATETIME DEFAULT (CURRENT_TIMESTAMP),
                    FOREIGN KEY(user_id) REFERENCES users (id),
                    CONSTRAINT uq_user_milestone UNIQUE (user_id, milestone_key)
                )
            """))
            connection.execute(text("CREATE INDEX ix_user_milestones_id ON user_milestones (id)"))
            connection.execute(text("CREATE INDEX ix_user_milestones_user_id ON user_milestones (user_id)"))
