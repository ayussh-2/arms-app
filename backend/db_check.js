const { Client } = require("pg");
const fs = require("fs");
const path = require("path");

// Manually load .env variables if running under standard Node without Bun
if (!process.env.DB_URL) {
    try {
        const envPath = path.join(__dirname, ".env");
        if (fs.existsSync(envPath)) {
            const envContent = fs.readFileSync(envPath, "utf8");
            const match = envContent.match(/DB_URL\s*=\s*["']?([^"'\r\n]+)["']?/);
            if (match && match[1]) {
                process.env.DB_URL = match[1];
            }
        }
    } catch (e) {
        console.error("Error reading .env file:", e.message);
    }
}

const dbUrl = process.env.DB_URL;

async function main() {
    if (!dbUrl) {
        console.error("❌ Error: DB_URL environment variable is not defined in your .env file!");
        process.exit(1);
    }

    console.log("🔍 Diagnostic Connection String:", dbUrl.replace(/:([^:@]+)@/, ":******@")); // Mask password for logs

    // Check if the URL credentials look like they need URL-encoding
    const unencodedMatch = dbUrl.match(/:([^:@]+)@/);
    if (unencodedMatch) {
        const password = unencodedMatch[1];
        if (password.includes("@") || password.includes("$")) {
            console.warn("\n⚠️ WARNING: Your password contains '@' or '$' characters and does not appear to be URL-encoded.");
            console.warn("This will break URL parsing and cause DNS ENOTFOUND errors!");
            console.warn("URL-encoded version of your password should be used instead.");
            const encodedPassword = encodeURIComponent(password);
            console.warn(`Suggested encoded password: ${encodedPassword}`);
        }
    }

    const client = new Client({
        connectionString: dbUrl,
        ssl: { rejectUnauthorized: false }
    });

    try {
        console.log("\nAttempting connection to PostgreSQL database...");
        await client.connect();
        console.log("✅ Successfully connected to your PostgreSQL database!");

        const res = await client.query(`
            SELECT table_name 
            FROM information_schema.tables 
            WHERE table_schema = 'public'
        `);
        
        console.log("\nExisting Tables in public schema:");
        if (res.rows.length === 0) {
            console.log("None (Empty database). You should run the DDL schema in db.sql using your database GUI or editor.");
        } else {
            res.rows.forEach(row => console.log(`- ${row.table_name}`));
        }
    } catch (err) {
        console.error("\n❌ Database Connection Failed!");
        console.error("Error Details:", err.message);
        
        if (err.message.includes("ENOTFOUND")) {
            console.error("\n💡 TROUBLESHOOTING TIP:");
            console.error("This is usually a DNS / IPv6 resolution issue with Supabase direct connection strings.");
            console.error("Please switch to your Supabase project's TRANSACTION POOLER connection string (Port 6543) which has native IPv4 support.");
        } else if (err.message.includes("tenant/user")) {
            console.error("\n💡 TROUBLESHOOTING TIP:");
            console.error("The connection pooler accepted the request, but your project reference was not found.");
            console.error("Please verify that you copied the correct Transaction Pooler URL from your Supabase Dashboard -> Settings -> Database.");
        }
    } finally {
        await client.end();
    }
}

main();
