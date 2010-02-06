-- ------------------------------------------------------------
-- - mylog schema version: 3.1.1
-- - $Id: mylog-schema.sql 157 2010-02-06 02:54:39Z immute $
-- - $Rev: 157 $
-- - $Date: 2010-02-06 02:54:39 +0000 (Sat, 06 Feb 2010) $
-- ------------------------------------------------------------

SET search_path TO mylog;

CREATE TABLE "networks" (
  "id"          SERIAL UNIQUE,
  "network"     CHAR(16) NOT NULL,
  PRIMARY KEY   ("id")
);
CREATE UNIQUE INDEX "idx_network" ON "networks" ("network");
   

CREATE TABLE "channels" (
  "id"          SERIAL UNIQUE,
  "channel"     CHAR(32) NOT NULL,
  PRIMARY KEY   ("id")
);
CREATE UNIQUE INDEX "idx_channel" ON "channels" ("channel");


CREATE TABLE "reasons" (
  "id"          SERIAL UNIQUE,
  "reason"      VARCHAR(510) NOT NULL,
  PRIMARY KEY   ("id")
);
CREATE UNIQUE INDEX "idx_reason" on "reasons" ("reason");


CREATE TABLE "user_id" (
  "id"          SERIAL UNIQUE,
  "network_id"  INTEGER NOT NULL,
  "nick"        CHAR(32) NOT NULL,
  "ident"       CHAR(10) NOT NULL,
  "hostname"    VARCHAR(64) NOT NULL,
  PRIMARY KEY   ("id"),
  CONSTRAINT "FK_userid_network" FOREIGN KEY ("network_id") REFERENCES "networks" ("id") ON DELETE CASCADE ON UPDATE CASCADE
);
CREATE UNIQUE INDEX "idx_nnih" ON "user_id" ("network_id","nick","ident","hostname");
CREATE INDEX "idx_network_id" on "user_id" ("network_id");
CREATE INDEX "idx_nick" on "user_id" ("nick");
CREATE INDEX "idx_ident" on "user_id" ("ident");
CREATE INDEX "idx_hostname" ON "user_id" ("hostname");





CREATE TABLE "joins" (
  "id"          SERIAL UNIQUE,
  "timestamp"   TIMESTAMP NOT NULL DEFAULT NOW(),
  "user_id"     INTEGER NOT NULL,
  "network_id"  INTEGER NOT NULL,
  "channel_id"  INTEGER NOT NULL,
  PRIMARY KEY   ("id"),
  CONSTRAINT "FK_joins_user_id" FOREIGN KEY ("user_id") REFERENCES "user_id" ("id") ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT "FK_joins_network_id" FOREIGN KEY ("network_id") REFERENCES "networks" ("id") ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT "FK_joins_channel_id" FOREIGN KEY ("channel_id") REFERENCES "channels" ("id") ON DELETE CASCADE ON UPDATE CASCADE
);
CREATE INDEX "idx_joins_timestamp" ON "joins" ("timestamp");


CREATE TABLE "kicks" (
  "id"              SERIAL UNIQUE,
  "timestamp"       TIMESTAMP NOT NULL DEFAULT NOW(),
  "kicked_user_id"  INTEGER NOT NULL,
  "kicker_user_id"  INTEGER NOT NULL,
  "network_id"      INTEGER NOT NULL,
  "channel_id"      INTEGER NOT NULL,
  "reason_id"       INTEGER NOT NULL,
  PRIMARY KEY   ("id"),
  CONSTRAINT "FK_kicks_kicked_id" FOREIGN KEY ("kicked_user_id") REFERENCES "user_id" ("id") ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT "FK_kicks_kicker_id" FOREIGN KEY ("kicker_user_id") REFERENCES "user_id" ("id") ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT "FK_kicks_network_id" FOREIGN KEY ("network_id") REFERENCES "networks" ("id") ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT "FK_kicks_channel_id" FOREIGN KEY ("channel_id") REFERENCES "channels" ("id") ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT "FK_kicks_reason_id" FOREIGN KEY ("reason_id") REFERENCES "reasons" ("id") ON DELETE CASCADE ON UPDATE CASCADE
);
CREATE INDEX "idx_kicks_timestamp" ON "kicks" ("timestamp");


CREATE TABLE "messages" (
  "id"          SERIAL UNIQUE,
  "timestamp"   TIMESTAMP NOT NULL DEFAULT NOW(),
  "user_id"     INTEGER NOT NULL,
  "network_id"  INTEGER NOT NULL,
  "channel_id"  INTEGER NOT NULL,
  "message"     TEXT NOT NULL,
  PRIMARY KEY   ("id"),
  CONSTRAINT "FK_messages_network" FOREIGN KEY ("network_id") REFERENCES "networks" ("id") ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT "FK_messages_channel" FOREIGN KEY ("channel_id") REFERENCES "channels" ("id") ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT "FK_messages_user" FOREIGN KEY ("user_id") REFERENCES "user_id" ("id") ON DELETE CASCADE ON UPDATE CASCADE
);
CREATE INDEX "idx_messages_timestamp" ON "messages" ("timestamp");


CREATE TABLE "pms" (
  "id"          SERIAL UNIQUE,
  "timestamp"   TIMESTAMP NOT NULL DEFAULT NOW(),
  "src"         INTEGER NOT NULL,
  "dst"         INTEGER NOT NULL,
  "message"     TEXT NOT NULL,
  PRIMARY KEY   ("id"),
  CONSTRAINT "FK_pms_src" FOREIGN KEY ("src") REFERENCES "user_id" ("id") ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT "FK_pms_dst" FOREIGN KEY ("dst") REFERENCES "user_id" ("id") ON DELETE CASCADE ON UPDATE CASCADE
);
CREATE INDEX "idx_pms_timestamp" ON "pms" ("timestamp");


CREATE TABLE "nick_changes" (
  "id"          SERIAL UNIQUE,
  "timestamp"   TIMESTAMP NOT NULL DEFAULT NOW(),
  "old_user_id" INTEGER NOT NULL,
  "new_user_id" INTEGER NOT NULL,
  "network_id"  INTEGER NOT NULL,
  PRIMARY KEY   ("id"),
  CONSTRAINT "FK_nickchanges_old_user_id" FOREIGN KEY ("old_user_id") REFERENCES "user_id" ("id") ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT "FK_nickchanges_new_user_id" FOREIGN KEY ("new_user_id") REFERENCES "user_id" ("id") ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT "FK_messages_network" FOREIGN KEY ("network_id") REFERENCES "networks" ("id") ON DELETE CASCADE ON UPDATE CASCADE
);
CREATE INDEX "idx_nickchanges_timestamp" ON "nick_changes" ("timestamp");


CREATE TABLE "parts" (
  "id"          SERIAL UNIQUE,
  "timestamp"   TIMESTAMP NOT NULL default NOW(),
  "user_id"     INTEGER NOT NULL,
  "network_id"  INTEGER NOT NULL,
  "channel_id"  INTEGER NOT NULL,
  "reason_id"   INTEGER NOT NULL,
  PRIMARY KEY   ("id"),
  CONSTRAINT "FK_parts_user_id" FOREIGN KEY ("user_id") REFERENCES "user_id" ("id") ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT "FK_parts_network_id" FOREIGN KEY ("network_id") REFERENCES "networks" ("id") ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT "FK_parts_channel_id" FOREIGN KEY ("channel_id") REFERENCES "channels" ("id") ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT "FK_parts_reason_id" FOREIGN KEY ("reason_id") REFERENCES "reasons" ("id") ON DELETE CASCADE ON UPDATE CASCADE
);
CREATE INDEX "idx_parts_timestamp" ON "parts" ("timestamp");


CREATE TABLE "quits" (
  "id"          SERIAL UNIQUE,
  "timestamp"   TIMESTAMP NOT NULL DEFAULT NOW(),
  "user_id"     INTEGER NOT NULL,
  "network_id"  INTEGER NOT NULL,
  "reason_id"   INTEGER NOT NULL,
  PRIMARY KEY   ("id"),
  CONSTRAINT "FK_quits_user_id" FOREIGN KEY ("user_id") REFERENCES "user_id" ("id") ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT "FK_quits_network_id" FOREIGN KEY ("network_id") REFERENCES "networks" ("id") ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT "FK_quits_reason_id" FOREIGN KEY ("reason_id") REFERENCES "reasons" ("id") ON DELETE CASCADE ON UPDATE CASCADE
);
CREATE INDEX "idx_quits_timestamp" ON "quits" ("timestamp");


CREATE TABLE "topics" (
  "id"          SERIAL,
  "timestamp"   TIMESTAMP NOT NULL DEFAULT NOW(),
  "user_id"     INTEGER NOT NULL,
  "network_id"  INTEGER NOT NULL,
  "channel_id"  INTEGER NOT NULL,
  "topic"       TEXT NOT NULL,
  PRIMARY KEY   ("id"),
  CONSTRAINT "FK_topics_user_id" FOREIGN KEY ("user_id") REFERENCES "user_id" ("id") ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT "FK_topics_network_id" FOREIGN KEY ("network_id") REFERENCES "networks" ("id") ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT "FK_topics_channel_id" FOREIGN KEY ("channel_id") REFERENCES "channels" ("id") ON DELETE CASCADE ON UPDATE CASCADE
);
CREATE INDEX "idx_topics_timestamp" ON "topics" ("timestamp");
