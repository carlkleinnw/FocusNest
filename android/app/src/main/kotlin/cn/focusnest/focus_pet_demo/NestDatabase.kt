package cn.focusnest.focus_pet_demo

import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper
import org.json.JSONObject

// App-private SQLite. No user state is stored on external/shared storage.
class NestDatabase(context: Context) : SQLiteOpenHelper(context, "focusnest.db", null, 1) {
    override fun onCreate(db: SQLiteDatabase) {
        db.execSQL("CREATE TABLE snapshots (name TEXT PRIMARY KEY, payload TEXT NOT NULL)")
    }
    override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) = Unit
    @Synchronized fun read(name: String): String? = readableDatabase.query(
        "snapshots", arrayOf("payload"), "name = ?", arrayOf(name), null, null, null
    ).use { if (it.moveToFirst()) it.getString(0) else null }
    @Synchronized fun write(name: String, payload: String) {
        val values = ContentValues().apply { put("name", name); put("payload", payload) }
        check(writableDatabase.insertWithOnConflict("snapshots", null, values, SQLiteDatabase.CONFLICT_REPLACE) != -1L) { "本地保存失败" }
    }
    @Synchronized fun beginFocus(rule: JSONObject, snapshot: String) {
        val db = writableDatabase
        db.beginTransaction()
        try {
            write("protection", rule.toString())
            write("state", snapshot)
            db.setTransactionSuccessful()
        } finally { db.endTransaction() }
    }
    fun rule(): JSONObject? = read("protection")?.let { JSONObject(it) }
    fun clearFocus() = write("protection", "{}")
}
