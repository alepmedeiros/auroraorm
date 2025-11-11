// SimpleORM compile-time configuration.
// You can set the default PostgreSQL schema here at compile time.
// If left empty, SimpleORM will default to 'public'.
// Example:
//   const SIMPLEORM_COMPILETIME_SCHEMA = 'financeiro';
//   or keep as empty string to use 'public'.
// Default schema for PostgreSQL when using the sample.
// Set to 'simpleorm' per user's preference for this example.
const SIMPLEORM_COMPILETIME_SCHEMA = 'simpleorm';

// Compile-time flag to enable FireDAC flat-file monitoring in samples.
// When TRUE, the sample will log executed SQL to fd_monitor.log via TFDMoniFlatFileLink.
// Set to FALSE to disable logging.
const SIMPLEORM_ENABLE_MONITOR = False;

// Compile-time defaults for PostgreSQL timeouts (in seconds)
// Adjust as needed for your environment. These only affect the sample connection code.
const SIMPLEORM_STATEMENT_TIMEOUT_SECS = 5; // applies to SET statement_timeout = '5s'
const SIMPLEORM_LOCK_TIMEOUT_SECS = 3;      // applies to SET lock_timeout = '3s'