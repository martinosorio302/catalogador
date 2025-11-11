namespace CatalogadorEsSalud.Models
{
    public class ClassificationResult
    {
        public string? DocumentId { get; set; }
        public string? Classification { get; set; }
        public string? Serie { get; set; }
        public string? Subserie { get; set; }
        public double Confidence { get; set; }
        public string? TrdCode { get; set; }
        public int? RetencionAnios { get; set; }
    }

    public class DocumentMetadata
    {
        public string? FileName { get; set; }
        public long FileSize { get; set; }
        public string? FileType { get; set; }
        public int PageCount { get; set; }
        public DateTime UploadDate { get; set; }
    }

    public class ProcessingStatus
    {
        public string? DocumentId { get; set; }
        public string? Status { get; set; }
        public int Progress { get; set; }
        public string? Message { get; set; }
    }
}
