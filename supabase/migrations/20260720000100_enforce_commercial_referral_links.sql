CREATE OR REPLACE FUNCTION app.enforce_commercial_referral_link()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.ref_link := 'https://app.academiea.com/ref/' || NEW.ref_code;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_enforce_commercial_referral_link ON app.commercial_profiles;

CREATE TRIGGER trg_enforce_commercial_referral_link
BEFORE INSERT OR UPDATE OF ref_code, ref_link ON app.commercial_profiles
FOR EACH ROW
EXECUTE FUNCTION app.enforce_commercial_referral_link();
