-- Fonction updated_at pour whiteboard_projects
CREATE OR REPLACE FUNCTION app.whiteboard_projects_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger updated_at pour whiteboard_projects
DROP TRIGGER IF EXISTS whiteboard_projects_updated_at_trigger ON app.whiteboard_projects;
CREATE TRIGGER whiteboard_projects_updated_at_trigger
  BEFORE UPDATE ON app.whiteboard_projects
  FOR EACH ROW
  EXECUTE FUNCTION app.whiteboard_projects_updated_at();

-- Fonction updated_at pour whiteboard_ai_generations
CREATE OR REPLACE FUNCTION app.whiteboard_ai_generations_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger updated_at pour whiteboard_ai_generations
DROP TRIGGER IF EXISTS whiteboard_ai_generations_updated_at_trigger ON app.whiteboard_ai_generations;
CREATE TRIGGER whiteboard_ai_generations_updated_at_trigger
  BEFORE UPDATE ON app.whiteboard_ai_generations
  FOR EACH ROW
  EXECUTE FUNCTION app.whiteboard_ai_generations_updated_at();
