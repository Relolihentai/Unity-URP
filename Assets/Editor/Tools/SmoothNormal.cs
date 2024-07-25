using System.Collections.Generic;
using System.Linq;
using UnityEditor;
using UnityEngine;
public struct NormalWeight {
    public Vector3 normal;
    public float weight;
}
public class SmoothNormal : EditorWindow
{
    [MenuItem("Tools/Smooth Normal")]
    private static void OpenWindows()
    {
        GetWindow<SmoothNormal>(false, "smooth normal", true).Show();
    }

    private Mesh mesh;
    private void OnGUI()
    {
        if (Selection.activeGameObject is null)
        {
            EditorGUILayout.LabelField("请选择目标模型FBX");
            return;
        }
        
        Transform selectedObject = Selection.activeGameObject.transform;
        bool useSkinMesh = false;
        var meshFilter = selectedObject.GetComponent<MeshFilter>();
        var skinnedMeshRenderer = selectedObject.GetComponent<SkinnedMeshRenderer>();
        if (meshFilter)
        {
            useSkinMesh = false;
            mesh = meshFilter.sharedMesh;
        } else if (skinnedMeshRenderer)
        {
            useSkinMesh = true;
            mesh = skinnedMeshRenderer.sharedMesh;
        }
        else
        {
            EditorGUILayout.LabelField("请选择拥有mesh相关组件的物体");
            return;
        }

        EditorGUILayout.BeginVertical();
        EditorGUILayout.LabelField("选择的物体为：" + selectedObject.name);
        EditorGUILayout.LabelField("当前选择的物体的网格为：" + mesh.name);
        if (GUILayout.Button("另存并替换网格"))
        {
            mesh = ExportMesh(mesh, "Assets/");
            if (useSkinMesh)
                skinnedMeshRenderer.sharedMesh = mesh;
            else
                meshFilter.sharedMesh = mesh;
        }
        
        if( GUILayout.Button( "写入切线空间平滑法线到顶点色" ) ) {
            var normals = GenerateSmoothNormals( mesh ); //获取上一步的平滑后法线（切线空间）
            /*Color[] vertCols = new Color[normals.Length];
            vertCols = vertCols.Select( ( col, ind ) => new Color( normals[ind].x, normals[ind].y, normals[ind].z, mesh.colors[ind].a ) ).ToArray(); //将法线每一项的向量转化为颜色*/
            mesh.SetUVs(7, normals);
        }
        EditorGUILayout.EndVertical();
    }

    public static Mesh ExportMesh(Mesh mesh, string path)
    {
        Mesh meshTmp = new Mesh();
        CopyMesh(mesh, meshTmp);
        meshTmp.name = meshTmp.name + "_SmoothNormal";
        AssetDatabase.CreateAsset(meshTmp, path + meshTmp.name + ".asset");
        AssetDatabase.SaveAssets();
        AssetDatabase.Refresh();
        return meshTmp;
    }

    public static void CopyMesh(Mesh src, Mesh dest)
    {
        dest.Clear();
        dest.vertices = src.vertices;
        List<Vector4> uvs = new List<Vector4>();
        for (int i = 0; i < 8; i++)
        {
            src.GetUVs(i, uvs);
            dest.SetUVs(i, uvs);
        }

        dest.normals = src.normals;
        dest.tangents = src.tangents;
        dest.boneWeights = src.boneWeights;
        dest.colors = src.colors;
        dest.colors32 = src.colors32;
        dest.bindposes = src.bindposes;
        
        Vector3[] deltaVertices = new Vector3[src.vertexCount];
        Vector3[] deltaNormals = new Vector3[src.vertexCount];
        Vector3[] deltaTangents = new Vector3[src.vertexCount];
        for( int shapeIndex = 0; shapeIndex < src.blendShapeCount; shapeIndex++ ) {
            string shapeName = src.GetBlendShapeName( shapeIndex );
            int frameCount = src.GetBlendShapeFrameCount( shapeIndex );
            for( int frameIndex = 0; frameIndex < frameCount; frameIndex++ ) {
                float frameWeight = src.GetBlendShapeFrameWeight( shapeIndex, frameIndex );
                src.GetBlendShapeFrameVertices( shapeIndex, frameIndex, deltaVertices, deltaNormals, deltaTangents );
                dest.AddBlendShapeFrame( shapeName, frameWeight, deltaVertices, deltaNormals, deltaTangents );
            }
        }

        dest.subMeshCount = src.subMeshCount;
        for (int i = 0; i < src.subMeshCount; i++)
            dest.SetIndices(src.GetIndices(i), src.GetTopology(i), i);
        dest.name = src.name;
    }

    private static Vector3[] GenerateSmoothNormals(Mesh srcMesh)
    {
        Dictionary<Vector3, List<NormalWeight>> normalDict = new Dictionary<Vector3, List<NormalWeight>>();
        var triangles = srcMesh.triangles;
        var vertices = srcMesh.vertices;
        var normals = srcMesh.normals;
        var tangents = srcMesh.tangents;
        var smoothNormals = srcMesh.normals;

        for (int i = 0; i < triangles.Length - 3; i += 3)
        {
            int[] triangle = new int[] { triangles[i], triangles[i + 1], triangles[i + 2] };
            for (int j = 0; j < 3; j++)
            {
                int vertexIndex = triangle[j];
                Vector3 vertex = vertices[vertexIndex];
                if (!normalDict.ContainsKey(vertex))
                {
                    normalDict.Add(vertex, new List<NormalWeight>());
                }

                NormalWeight nw;
                Vector3 lineA = Vector3.zero;
                Vector3 lineB = Vector3.zero;
                if (j == 0)
                {
                    lineA = vertices[triangle[1]] - vertex;
                    lineB = vertices[triangle[2]] - vertex;
                }
                else if (j == 1)
                {
                    lineA = vertices[triangle[2]] - vertex;
                    lineB = vertices[triangle[0]] - vertex;
                }
                else
                {
                    lineA = vertices[triangle[0]] - vertex;
                    lineB = vertices[triangle[1]] - vertex;
                }

                lineA *= 10000.0f;
                lineB *= 10000.0f;
                float angle =
                    Mathf.Acos(Mathf.Max(Mathf.Min(Vector3.Dot(lineA, lineB) / (lineA.magnitude * lineB.magnitude), 1),
                        -1));
                nw.normal = Vector3.Cross(lineA, lineB).normalized;
                nw.weight = angle;
                normalDict[vertex].Add(nw);
            }
        }

        for (int i = 0; i < vertices.Length; i++)
        {
            Vector3 vertex = vertices[i];
            if (!normalDict.ContainsKey(vertex))
            {
                continue;
            }

            List<NormalWeight> normalList = normalDict[vertex];

            Vector3 smoothNormal = Vector3.zero;
            float weightSum = 0;
            for (int j = 0; j < normalList.Count; j++)
            {
                NormalWeight nw = normalList[j];
                weightSum += nw.weight;
            }

            for (int j = 0; j < normalList.Count; j++)
            {
                NormalWeight nw = normalList[j];
                smoothNormal += nw.normal * nw.weight / weightSum;
            }
            
            smoothNormal = smoothNormal.normalized;
            smoothNormals[i] = smoothNormal;

            var normal = normals[i];
            var tangent = tangents[i];
            var binormal = (Vector3.Cross(normal, tangent) * tangent.w).normalized;
            var tbn = new Matrix4x4(tangent, binormal, normal, Vector3.zero);
            tbn = tbn.transpose;
            smoothNormals[i] = tbn.MultiplyVector(smoothNormals[i]).normalized;
        }
        return smoothNormals;
    }
}
