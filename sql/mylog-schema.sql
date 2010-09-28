-- ------------------------------------------------------------
-- -  Mylog PostgreSQL Schema Version: 3.1.2
-- ------------------------------------------------------------

DROP SCHEMA IF EXISTS "mylog";
CREATE SCHEMA "mylog";
SET search_path TO "mylog";

CREATE TABLE "networks" (
  "id"          SERIAL UNIQUE,
  "network"     CHAR(16) NOT NULL
);
CREATE UNIQUE INDEX "idx_network" ON "networks" ("network");

CREATE TABLE "channels" (
  "id"          SERIAL UNIQUE,
  "channel"     CHAR(32) NOT NULL
);
CREATE UNIQUE INDEX "idx_channel" ON "channels" ("channel");

CREATE TABLE "reasons" (
  "id"          SERIAL UNIQUE,
  "reason"      VARCHAR(510) NOT NULL
);
CREATE UNIQUE INDEX "idx_reason" on "reasons" ("reason");


CREATE TABLE "users" (
  "id"          SERIAL UNIQUE,
  "network_id"  INTEGER NOT NULL,
  "nick"        CHAR(32) NOT NULL,
  "ident"       CHAR(10) NOT NULL,
  "hostname"    VARCHAR(64) NOT NULL,
  CONSTRAINT "FK_users-networks" FOREIGN KEY ("network_id") REFERENCES "networks" ("id") ON DELETE CASCADE ON UPDATE CASCADE
);
CREATE UNIQUE INDEX "idx_nnih" ON "users" ("network_id","nick","ident","hostname");
CREATE INDEX "idx_network_id" on "users" ("network_id");
CREATE INDEX "idx_nick" on "users" ("nick");
CREATE INDEX "idx_ident" on "users" ("ident");
CREATE INDEX "idx_hostname" ON "users" ("hostname");






CREATE TABLE "joins" (
  "id"          SERIAL UNIQUE,
  "timestamp"   TIMESTAMP without time zone NOT NULL,
  "user_id"     INTEGER NOT NULL,
  "network_id"  INTEGER NOT NULL,
  "channel_id"  INTEGER NOT NULL,
  CONSTRAINT "FK_joins-user_id" FOREIGN KEY ("user_id") REFERENCES "users" ("id") ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT "FK_joins-network_id" FOREIGN KEY ("network_id") REFERENCES "networks" ("id") ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT "FK_joins-channel_id" FOREIGN KEY ("channel_id") REFERENCES "channels" ("id") ON DELETE CASCADE ON UPDATE CASCADE
);
CREATE INDEX "idx_joins_timestamp" ON "joins" ("timestamp");


CREATE TABLE "kicks" (
  "id"              SERIAL UNIQUE,
  "timestamp"       TIMESTAMP without time zone NOT NULL,
  "kicked_user_id"  INTEGER NOT NULL,
  "kicker_user_id"  INTEGER NOT NULL,
  "network_id"      INTEGER NOT NULL,
  "channel_id"      INTEGER NOT NULL,
  "reason_id"       INTEGER NOT NULL,
  CONSTRAINT "FK_kicks-kicked_id" FOREIGN KEY ("kicked_user_id") REFERENCES "users" ("id") ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT "FK_kicks-kicker_id" FOREIGN KEY ("kicker_user_id") REFERENCES "users" ("id") ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT "FK_kicks-network_id" FOREIGN KEY ("network_id") REFERENCES "networks" ("id") ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT "FK_kicks-channel_id" FOREIGN KEY ("channel_id") REFERENCES "channels" ("id") ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT "FK_kicks-reason_id" FOREIGN KEY ("reason_id") REFERENCES "reasons" ("id") ON DELETE CASCADE ON UPDATE CASCADE
);
CREATE INDEX "idx_kicks_timestamp" ON "kicks" ("timestamp");



CREATE TABLE "messages" (
  "id"          SERIAL UNIQUE,
  "timestamp"   TIMESTAMP without time zone NOT NULL,
  "user_id"     INTEGER NOT NULL,
  "network_id"  INTEGER NOT NULL,
  "channel_id"  INTEGER NOT NULL,
  "message"     TEXT NOT NULL,
  CONSTRAINT "FK_messages-network_id" FOREIGN KEY ("network_id") REFERENCES "networks" ("id") ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT "FK_messages-channel_id" FOREIGN KEY ("channel_id") REFERENCES "channels" ("id") ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT "FK_messages-user_id" FOREIGN KEY ("user_id") REFERENCES "users" ("id") ON DELETE CASCADE ON UPDATE CASCADE
);
CREATE INDEX "idx_messages_timestamp" ON "messages" ("timestamp");


CREATE TABLE "nick_changes" (
  "id"          SERIAL UNIQUE,
  "timestamp"   TIMESTAMP without time zone NOT NULL,
  "old_user_id" INTEGER NOT NULL,
  "new_user_id" INTEGER NOT NULL,
  "network_id"  INTEGER NOT NULL,
  CONSTRAINT "FK_nickchanges-old_user_id" FOREIGN KEY ("old_user_id") REFERENCES "users" ("id") ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT "FK_nickchanges-new_user_id" FOREIGN KEY ("new_user_id") REFERENCES "users" ("id") ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT "FK_nickchanges-network_id" FOREIGN KEY ("network_id") REFERENCES "networks" ("id") ON DELETE CASCADE ON UPDATE CASCADE
);
CREATE INDEX "idx_nickchanges_timestamp" ON "nick_changes" ("timestamp");


CREATE TABLE "parts" (
  "id"          SERIAL UNIQUE,
  "timestamp"   TIMESTAMP without time zone NOT NULL,
  "user_id"     INTEGER NOT NULL,
  "network_id"  INTEGER NOT NULL,
  "channel_id"  INTEGER NOT NULL,
  "reason_id"   INTEGER NOT NULL,
  CONSTRAINT "FK_parts-user_id" FOREIGN KEY ("user_id") REFERENCES "users" ("id") ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT "FK_parts-network_id" FOREIGN KEY ("network_id") REFERENCES "networks" ("id") ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT "FK_parts-channel_id" FOREIGN KEY ("channel_id") REFERENCES "channels" ("id") ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT "FK_parts-reason_id" FOREIGN KEY ("reason_id") REFERENCES "reasons" ("id") ON DELETE CASCADE ON UPDATE CASCADE
);
CREATE INDEX "idx_parts_timestamp" ON "parts" ("timestamp");


CREATE TABLE "quits" (
  "id"          SERIAL UNIQUE,
  "timestamp"   TIMESTAMP without time zone NOT NULL,
  "user_id"     INTEGER NOT NULL,
  "network_id"  INTEGER NOT NULL,
  "reason_id"   INTEGER NOT NULL,
  CONSTRAINT "FK_quits-user_id" FOREIGN KEY ("user_id") REFERENCES "users" ("id") ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT "FK_quits-network_id" FOREIGN KEY ("network_id") REFERENCES "networks" ("id") ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT "FK_quits-reason_id" FOREIGN KEY ("reason_id") REFERENCES "reasons" ("id") ON DELETE CASCADE ON UPDATE CASCADE
);
CREATE INDEX "idx_quits_timestamp" ON "quits" ("timestamp");

