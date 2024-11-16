import os

class Config:
    SECRET_KEY = 'feb31a36daeb08de122f7afa2930c8aa95d47761bd378138'
    SQLALCHEMY_DATABASE_URI = 'mysql+pymysql://username:password@192.168.1.12/cred'
    SQLALCHEMY_TRACK_MODIFICATIONS = False
    UPLOAD_FOLDER = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'static', 'uploads')
    MAX_CONTENT_LENGTH = 16 * 1024 * 1024
    ALLOWED_EXTENSIONS = {'png', 'jpg', 'jpeg', 'gif'}