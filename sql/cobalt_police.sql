CREATE TABLE IF NOT EXISTS `police_charges` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `category` VARCHAR(100) NOT NULL DEFAULT '',
  `code` VARCHAR(50) NOT NULL DEFAULT '',
  `title` VARCHAR(255) NOT NULL,
  `description` TEXT NOT NULL,
  `class` ENUM('felony', 'misdemeanor', 'infraction') NOT NULL DEFAULT 'misdemeanor',
  `months` INT UNSIGNED NOT NULL DEFAULT 0,
  `fine` INT UNSIGNED NOT NULL DEFAULT 0,
  `points` INT UNSIGNED NOT NULL DEFAULT 0,
  `stackable` TINYINT(1) NOT NULL DEFAULT 1,
  PRIMARY KEY (`id`),
  KEY `category_title` (`category`, `title`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `police_cases` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `kind` ENUM('incident', 'report') NOT NULL DEFAULT 'incident',
  `status` ENUM('draft', 'filed') NOT NULL DEFAULT 'draft',
  `title` VARCHAR(255) NOT NULL DEFAULT '',
  `location` VARCHAR(255) NOT NULL DEFAULT '',
  `coords` JSON DEFAULT NULL,
  `narrative` TEXT NOT NULL,
  `author` VARCHAR(100) NOT NULL DEFAULT '',
  `author_cid` VARCHAR(50) DEFAULT NULL,
  `occurred_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `kind_occurred_at` (`kind`, `occurred_at`),
  KEY `status_occurred_at` (`status`, `occurred_at`),
  KEY `occurred_at` (`occurred_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `police_case_people` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `incident_id` INT UNSIGNED NOT NULL,
  `role` ENUM('officer', 'suspect', 'witness') NOT NULL,
  `citizenid` VARCHAR(50) DEFAULT NULL,
  `name` VARCHAR(100) NOT NULL DEFAULT '',
  `charges` JSON DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `incident_role` (`incident_id`, `role`),
  KEY `citizenid` (`citizenid`),
  CONSTRAINT `police_case_people_incident_fk` FOREIGN KEY (`incident_id`) REFERENCES `police_cases` (`id`) ON DELETE CASCADE,
  CONSTRAINT `police_case_people_citizenid_fk` FOREIGN KEY (`citizenid`) REFERENCES `players` (`citizenid`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `police_evidence` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `type` ENUM('photo', 'item', 'forensic') NOT NULL DEFAULT 'photo',
  `title` VARCHAR(255) NOT NULL DEFAULT '',
  `description` TEXT NOT NULL,
  `image` VARCHAR(512) NOT NULL DEFAULT '',
  `location` VARCHAR(255) NOT NULL DEFAULT '',
  `citizenid` VARCHAR(50) DEFAULT NULL,
  `incident_id` INT UNSIGNED DEFAULT NULL,
  `collected_by` VARCHAR(100) NOT NULL DEFAULT '',
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `type_created_at` (`type`, `created_at`),
  KEY `citizenid` (`citizenid`),
  KEY `incident_id` (`incident_id`),
  CONSTRAINT `police_evidence_citizenid_fk` FOREIGN KEY (`citizenid`) REFERENCES `players` (`citizenid`) ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT `police_evidence_incident_fk` FOREIGN KEY (`incident_id`) REFERENCES `police_cases` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `police_convictions` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `citizenid` VARCHAR(50) NOT NULL,
  `charge_id` INT UNSIGNED DEFAULT NULL,
  `title` VARCHAR(255) NOT NULL,
  `code` VARCHAR(50) NOT NULL DEFAULT '',
  `class` ENUM('felony', 'misdemeanor', 'infraction') NOT NULL DEFAULT 'misdemeanor',
  `counts` INT UNSIGNED NOT NULL DEFAULT 1,
  `months` INT UNSIGNED NOT NULL DEFAULT 0,
  `fine` INT UNSIGNED NOT NULL DEFAULT 0,
  `points` INT UNSIGNED NOT NULL DEFAULT 0,
  `incident_id` INT UNSIGNED DEFAULT NULL,
  `sentenced_by` VARCHAR(50) DEFAULT NULL,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `citizenid_created_at` (`citizenid`, `created_at`),
  KEY `incident_id` (`incident_id`),
  CONSTRAINT `police_convictions_citizenid_fk` FOREIGN KEY (`citizenid`) REFERENCES `players` (`citizenid`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `police_convictions_incident_fk` FOREIGN KEY (`incident_id`) REFERENCES `police_cases` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `police_sentences` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `citizenid` VARCHAR(50) NOT NULL,
  `months` INT UNSIGNED NOT NULL,
  `remaining` INT UNSIGNED NOT NULL,
  `reason` VARCHAR(255) NOT NULL DEFAULT '',
  `incident_id` INT UNSIGNED DEFAULT NULL,
  `confiscation_id` VARCHAR(64) DEFAULT NULL,
  `sentenced_by` VARCHAR(50) DEFAULT NULL,
  `status` ENUM('active', 'served', 'released') NOT NULL DEFAULT 'active',
  `sentenced_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `ended_at` DATETIME DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `citizenid_status` (`citizenid`, `status`),
  CONSTRAINT `police_sentences_citizenid_fk` FOREIGN KEY (`citizenid`) REFERENCES `players` (`citizenid`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `police_sentences_incident_fk` FOREIGN KEY (`incident_id`) REFERENCES `police_cases` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `police_warrants` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `citizenid` VARCHAR(50) NOT NULL,
  `type` ENUM('arrest', 'search', 'bench') NOT NULL DEFAULT 'arrest',
  `title` VARCHAR(255) NOT NULL DEFAULT '',
  `description` TEXT NOT NULL,
  `status` ENUM('active', 'served', 'cancelled', 'expired') NOT NULL DEFAULT 'active',
  `issued_by` VARCHAR(100) NOT NULL DEFAULT '',
  `expires_at` DATETIME DEFAULT NULL,
  `incident_id` INT UNSIGNED DEFAULT NULL,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `citizenid_status` (`citizenid`, `status`),
  KEY `status_expires_at` (`status`, `expires_at`),
  KEY `status_created_at` (`status`, `created_at`),
  CONSTRAINT `police_warrants_citizenid_fk` FOREIGN KEY (`citizenid`) REFERENCES `players` (`citizenid`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `police_bolos` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `type` ENUM('person', 'vehicle') NOT NULL DEFAULT 'person',
  `department` VARCHAR(50) NOT NULL DEFAULT 'police',
  `title` VARCHAR(255) NOT NULL DEFAULT '',
  `description` TEXT NOT NULL,
  `citizenid` VARCHAR(50) DEFAULT NULL,
  `plate` VARCHAR(16) DEFAULT NULL,
  `person_name` VARCHAR(100) NOT NULL DEFAULT '',
  `last_seen` VARCHAR(255) NOT NULL DEFAULT '',
  `status` ENUM('active', 'cancelled') NOT NULL DEFAULT 'active',
  `issued_by` VARCHAR(100) NOT NULL DEFAULT '',
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `status_created_at` (`status`, `created_at`),
  KEY `plate` (`plate`),
  KEY `citizenid` (`citizenid`),
  CONSTRAINT `police_bolos_citizenid_fk` FOREIGN KEY (`citizenid`) REFERENCES `players` (`citizenid`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `police_bulletins` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `department` VARCHAR(50) NOT NULL,
  `title` VARCHAR(255) NOT NULL DEFAULT '',
  `body` TEXT NOT NULL,
  `pinned` TINYINT(1) NOT NULL DEFAULT 0,
  `author` VARCHAR(100) NOT NULL DEFAULT '',
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `pinned_created_at` (`pinned`, `created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `police_profiles` (
  `citizenid` VARCHAR(50) NOT NULL,
  `notes` TEXT NOT NULL,
  `image` VARCHAR(512) NOT NULL DEFAULT '',
  PRIMARY KEY (`citizenid`),
  CONSTRAINT `police_profiles_citizenid_fk` FOREIGN KEY (`citizenid`) REFERENCES `players` (`citizenid`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `police_tags` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `name` VARCHAR(100) NOT NULL,
  `color` CHAR(7) NOT NULL DEFAULT '#3F3F46',
  PRIMARY KEY (`id`),
  UNIQUE KEY `name` (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `police_citizen_tags` (
  `citizenid` VARCHAR(50) NOT NULL,
  `tag_id` INT UNSIGNED NOT NULL,
  PRIMARY KEY (`citizenid`, `tag_id`),
  KEY `tag_id` (`tag_id`),
  CONSTRAINT `police_citizen_tags_tag_fk` FOREIGN KEY (`tag_id`) REFERENCES `police_tags` (`id`) ON DELETE CASCADE,
  CONSTRAINT `police_citizen_tags_citizenid_fk` FOREIGN KEY (`citizenid`) REFERENCES `players` (`citizenid`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `police_certificates` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `name` VARCHAR(100) NOT NULL,
  `department` VARCHAR(50) NOT NULL DEFAULT 'police',
  PRIMARY KEY (`id`),
  UNIQUE KEY `name` (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `police_officer_certificates` (
  `citizenid` VARCHAR(50) NOT NULL,
  `certificate_id` INT UNSIGNED NOT NULL,
  PRIMARY KEY (`citizenid`, `certificate_id`),
  KEY `certificate_id` (`certificate_id`),
  CONSTRAINT `police_officer_certificates_certificate_fk` FOREIGN KEY (`certificate_id`) REFERENCES `police_certificates` (`id`) ON DELETE CASCADE,
  CONSTRAINT `police_officer_certificates_citizenid_fk` FOREIGN KEY (`citizenid`) REFERENCES `players` (`citizenid`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `police_templates` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `kind` ENUM('incident', 'report') NOT NULL DEFAULT 'incident',
  `name` VARCHAR(100) NOT NULL,
  `content` TEXT NOT NULL,
  PRIMARY KEY (`id`),
  KEY `name` (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `police_ranks` (
  `department` VARCHAR(50) NOT NULL,
  `grade` INT UNSIGNED NOT NULL,
  `permissions` JSON NOT NULL,
  PRIMARY KEY (`department`, `grade`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `police_settings` (
  `id` TINYINT UNSIGNED NOT NULL DEFAULT 1,
  `data` JSON NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `police_clamps` (
  `plate` VARCHAR(16) NOT NULL,
  `placed_by` VARCHAR(50) NOT NULL,
  `placed_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`plate`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `police_stolen_vehicles` (
  `plate` VARCHAR(16) NOT NULL,
  `reported_by` VARCHAR(100) NOT NULL DEFAULT '',
  `reported_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`plate`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
