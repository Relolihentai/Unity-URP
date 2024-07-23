using System.IO;
using Unity.Mathematics;
using Unity.VisualScripting;
using UnityEngine;
[ExecuteInEditMode]
public class NoiseGenerator : MonoBehaviour
{
    private static Vector2 Floor(Vector2 p)
    {
        return new Vector2(Mathf.Floor(p.x), Mathf.Floor(p.y));
    }
    private static Vector2 Frac(Vector2 p)
    {
        return p - Floor(p);
    }
    private static Vector2 Sin(Vector2 p)
    {
        return new Vector2(Mathf.Sin(p.x), Mathf.Sin(p.y));
    }
    private static Vector2 Hash(Vector2 p)
    {
        p = new Vector2(Vector2.Dot(p, new Vector2(127.1f, 311.7f)),
            Vector2.Dot(p, new Vector2(269.5f, 183.3f)));
 
        return new Vector2(-1, -1) + 2.0f * Frac(Sin(p) * 43758.5453123f);
    }
    // 一阶
    private static float GetEaseCurves(float t)
    {
        return t * t * t * (t * (t * 6 - 15) + 10);
    }
    // 二阶
    private static Vector2 GetEaseCurves(Vector2 p)
    {
        return new Vector2(GetEaseCurves(p.x), GetEaseCurves(p.y));
    }
    public static float prelin_noise(Vector2 p)
    {
        Vector2 pi = Floor(p);
        Vector2 pf = p - pi;
 
        Vector2 w = GetEaseCurves(pf);
 
        float corner1 = Vector2.Dot(Hash(pi + Vector2.zero), pf - Vector2.zero);
        float corner2 = Vector2.Dot(Hash(pi + Vector2.right), pf - Vector2.right);
        float corner3 = Vector2.Dot(Hash(pi + Vector2.up), pf - Vector2.up);
        float corner4 = Vector2.Dot(Hash(pi + Vector2.one), pf - Vector2.one);
 
        return Mathf.Lerp(Mathf.Lerp(corner1, corner2, w.x),
            Mathf.Lerp(corner3, corner4, w.x),
            w.y);
    }
    private static float fire_noise_base(Vector2 p)
    {
        const float K1 = 0.366025404f;//(sqrt(3)-1)/2)
        const float K2 = 0.211324865f;//(3-sqrt(3))/6;

        float tmp_1 = (p.x + p.y) * K1;
        Vector2 i = Floor(p + new Vector2(tmp_1, tmp_1));
        float tmp_2 = (i.x + i.y) * K2;
        Vector2 a = p - (i - new Vector2(tmp_2, tmp_2));
        Vector2 o = (a.x < a.y) ? new Vector2(0.0f,1.0f) : new Vector2(1.0f,0.0f);
        Vector2 b= a - o + new Vector2(K2, K2);
        Vector2 c= a - Vector2.one + 2.0f * new Vector2(K2, K2);
    
        Vector3 h = math.max( Vector3.one * 0.5f - new Vector3(math.dot(a, a), math.dot(b, b), math.dot(c, c) ), Vector3.zero);

        Vector3 tmp_3 = Vector3.Scale(h, h);
        Vector3 tmp_4 = Vector3.Scale(tmp_3, tmp_3);
        Vector3 n =  Vector3.Scale(tmp_4, new Vector3( math.dot(a,Hash(i + Vector2.zero)), math.dot(b,Hash(i+o)), math.dot(c,Hash(i + Vector2.one))));
	
        return math.dot( n, new Vector3(70.0f, 70.0f, 70.0f) );
    }

    private static float fbm_fire_noise(Vector2 uv)
    {
        float f = 0.0f;
        uv *= 2f;
        f = 0.5f * fire_noise_base(uv);
        uv *= 2f;
        f += 0.25f * fire_noise_base(uv);
        uv *= 2f;
        f += 0.125f * fire_noise_base(uv);
        uv *= 2f;
        f += 0.0625f * fire_noise_base(uv);
        uv *= 2f;
        f += 0.5f;
        return f;
    }
    
    
    public int width = 512;  // 贴图宽度
    public int height = 512; // 贴图高度
    public float xOrg = 0f;  // 宽度偏移起点
    public float yOrg = 0f;  // 高度偏移起点
    public float scale = 15f; // 周期
 
    private Texture2D CreateTexture()
    {
        Texture2D tex = new Texture2D(width, height);
        Color[] pix = new Color[width * height];
 
        float y = 0f;
        while (y < height)
        {
            float x = 0f;
            while (x < width)
            {
                float xCoord = xOrg + x / width * scale;
                float yCoord = yOrg + y / height * scale;
                float sample = fbm_fire_noise(new Vector2(xCoord, yCoord));
                float tmp = (y / height) * 9 + 1;
                //sample -= 1 - math.log10(tmp);
                pix[(int)y * width + (int)x] = new Color(sample, sample, sample);
                x++;
            }
            y++;
        }
 
        tex.SetPixels(pix);
        tex.Apply();
 
        return tex;
    }
    public bool SaveTexture(string path)
    {
        if (File.Exists(path))
        {
            Debug.LogWarning("已有文件");
            return false;
        }
        
        Texture2D tex = CreateTexture();
        if (tex == null)
        {
            Debug.LogWarning("贴图为空");
            return false;
        }
 
        // 贴图转换为PNG图片
        byte[] texData = tex.EncodeToPNG();
 
        // 如果没有目录则创建目录
        int index = path.LastIndexOf('/');
        string dir = path.Remove(index);
        if (!Directory.Exists(dir))
        {
            Directory.CreateDirectory(dir);
        }
 
        // 贴图存储
        File.WriteAllBytes(path, texData);
 
        return true;
    }
}
