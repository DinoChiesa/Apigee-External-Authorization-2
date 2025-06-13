using System.Collections.Generic;
using System.Text.Json.Serialization;

namespace Server
{
    public class GsheetData
    {
        [JsonPropertyName("range")]
        public string Range { get; set; }

        [JsonPropertyName("majorDimension")]
        public string MajorDimension { get; set; }

        [JsonPropertyName("values")]
        public List<List<string>> Values { get; set; }

        public GsheetData Digest()
        {
            if (Values != null)
            {
                // Remove items from the Values list that are an empty list or null
                Values.RemoveAll(item => item == null || item.Count == 0);
            }
            return this;
        }
    }
}
