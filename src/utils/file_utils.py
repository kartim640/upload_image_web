import mimetypes
from flask import current_app

def allowed_file(filename):
    if not filename:
        return False
    if '.' not in filename:
        return False

    extension = filename.rsplit('.', 1)[1].lower()
    mime_type, _ = mimetypes.guess_type(filename)

    return extension in current_app.config['ALLOWED_EXTENSIONS'] and mime_type.startswith('image')