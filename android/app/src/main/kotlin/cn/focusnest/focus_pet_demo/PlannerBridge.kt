package cn.focusnest.focus_pet_demo

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject
import java.net.URL
import java.security.KeyStore
import java.util.concurrent.Executors
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec
import javax.net.ssl.HttpsURLConnection

/** Personal BYOK client: only the official HTTPS host; never returns or logs keys. */
class PlannerBridge(context: Context, messenger: BinaryMessenger) {
    private val prefs = context.getSharedPreferences("planner_secret_v1", Context.MODE_PRIVATE)
    private val executor = Executors.newSingleThreadExecutor()
    private val handler = Handler(Looper.getMainLooper())
    private val alias = "focusnest.deepseek.v1"
    init {
        MethodChannel(messenger, "focusnest/agent_v1").setMethodCallHandler { call, result ->
            when (call.method) {
                "settings" -> result.success(mapOf("configured" to prefs.contains("ciphertext"),
                    "model" to prefs.getString("model", "deepseek-flash")))
                "configure" -> {
                    try {
                        val model = call.argument<String>("model") ?: "deepseek-flash"
                        require(model in setOf("deepseek-flash", "deepseek-v4-pro", "deepseek-chat"))
                        val key = call.argument<String>("key")?.trim() ?: ""
                        val edit = prefs.edit().putString("model", model)
                        if (call.argument<Boolean>("remove") == true) {
                            edit.remove("ciphertext").remove("iv")
                        } else if (key.isNotEmpty()) {
                            require(key.length in 10..256 && key.all { it.code in 33..126 })
                            val cipher = Cipher.getInstance("AES/GCM/NoPadding")
                            cipher.init(Cipher.ENCRYPT_MODE, secret())
                            edit.putString("ciphertext", Base64.encodeToString(cipher.doFinal(key.toByteArray(Charsets.UTF_8)), Base64.NO_WRAP))
                            edit.putString("iv", Base64.encodeToString(cipher.iv, Base64.NO_WRAP))
                        }
                        check(edit.commit())
                        result.success(null)
                    } catch (_: Exception) { result.error("CONFIG_FAILED", "密钥保存失败，请检查输入后重试。", null) }
                }
                "request" -> {
                    val messages = call.argument<List<Map<String, String>>>("messages")
                    if (messages == null || messages.size !in 1..20 || messages.any {
                            it["role"] !in setOf("system", "user", "assistant") || (it["content"]?.length ?: 0) > 120_000 }) {
                        result.error("INVALID_REQUEST", "请求过长，请缩短目标后重试。", null)
                    } else executor.execute {
                        try {
                            val content = complete(messages)
                            handler.post { result.success(content) }
                        } catch (e: PlannerException) {
                            handler.post { result.error("AGENT_FAILED", e.message, null) }
                        } catch (_: Exception) {
                            handler.post { result.error("NETWORK_FAILED", "网络请求失败或超时，请检查网络后重试。", null) }
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
    private fun secret(): SecretKey {
        val store = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        (store.getKey(alias, null) as? SecretKey)?.let { return it }
        return KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore").apply {
            init(KeyGenParameterSpec.Builder(alias, KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE).build())
        }.generateKey()
    }
    private fun readKey(): String {
        val data = prefs.getString("ciphertext", null) ?: throw PlannerException("请先在设置页填写 DeepSeek API 密钥。")
        try {
            val iv = Base64.decode(prefs.getString("iv", ""), Base64.NO_WRAP)
            val cipher = Cipher.getInstance("AES/GCM/NoPadding")
            cipher.init(Cipher.DECRYPT_MODE, secret(), GCMParameterSpec(128, iv))
            return String(cipher.doFinal(Base64.decode(data, Base64.NO_WRAP)), Charsets.UTF_8)
        } catch (_: Exception) { throw PlannerException("密钥无法读取，请在设置页重新填写。") }
    }
    private fun complete(messages: List<Map<String, String>>): String {
        val key = readKey()
        val body = JSONObject().put("model", prefs.getString("model", "deepseek-flash"))
            .put("messages", JSONArray(messages)).put("stream", false)
            .put("thinking", JSONObject().put("type", "disabled"))
            .put("response_format", JSONObject().put("type", "json_object"))
            .put("max_tokens", 24000).put("temperature", 0.2).toString()
        val connection = URL("https://api.deepseek.com/chat/completions").openConnection() as HttpsURLConnection
        try {
            connection.connectTimeout = 15_000
            connection.readTimeout = 120_000
            connection.instanceFollowRedirects = false
            connection.requestMethod = "POST"
            connection.doOutput = true
            connection.setRequestProperty("Content-Type", "application/json; charset=utf-8")
            connection.setRequestProperty("Authorization", "Bearer $key")
            connection.outputStream.use { it.write(body.toByteArray(Charsets.UTF_8)) }
            val code = connection.responseCode
            if (code != 200) throw PlannerException(when(code) {
                401 -> "密钥无效，请在设置页重新填写。"
                402 -> "DeepSeek 余额不足，请检查账户。"
                429 -> "请求过于频繁，请稍后重试。"
                400, 422 -> "模型或请求不受支持，请在设置页检查模型。"
                else -> "DeepSeek 服务暂不可用（$code），请稍后重试。"
            })
            val bytes = connection.inputStream.use { it.readBytesLimited(2_000_000) }
            val response = JSONObject(String(bytes, Charsets.UTF_8))
            val choice = response.getJSONArray("choices").getJSONObject(0)
            if (choice.optString("finish_reason") != "stop") throw PlannerException("AI 输出不完整，未修改数据，请缩短计划周期后重试。")
            val content = choice.getJSONObject("message").getString("content")
            JSONObject(content)
            return content
        } finally { connection.disconnect() }
    }
    private fun java.io.InputStream.readBytesLimited(limit: Int): ByteArray {
        val out = java.io.ByteArrayOutputStream()
        val buffer = ByteArray(8192)
        while (true) {
            val n = read(buffer)
            if (n < 0) break
            if (out.size() + n > limit) throw PlannerException("AI 返回内容过长，请缩短计划周期后重试。")
            out.write(buffer, 0, n)
        }
        return out.toByteArray()
    }
    private class PlannerException(message: String): Exception(message)
}
