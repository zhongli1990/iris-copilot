/// Reference notes (stub) for the IRIS code import/export patterns used by
/// AIAgent.Engine.CodeManager.
///
/// The original reference file shipped here contained site-specific package
/// lists from a non-public production environment. It has been removed for
/// public distribution. The patterns themselves are documented inline in
/// AIAgent.Engine.CodeManager — see that class for the canonical usage.
///
/// Patterns referenced by AIAgent.Engine.CodeManager:
///   - $system.OBJ.ExportAllClassesIndividual(dir, flags, "", "", package)
///   - $system.OBJ.LoadDir(dir, flags)
///   - $system.OBJ.DeletePackage(package, flags)
///   - $system.OBJ.ExportHL7Schemas(file, flags)
///   - $system.OBJ.ImportHL7Schemas(file, flags)
///   - $system.OBJ.ExportLookups(file, flags)
///
/// This file is intentionally not part of the AIAgent deployment package
/// (deploy/generate-xml-export.py CLASS_ORDER) and is not loaded at runtime.
/// It exists only so legacy doc-comment references resolve.
Class VersionControl.UpdateBranch [ Abstract ]
{

}
