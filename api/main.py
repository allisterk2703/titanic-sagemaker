# api/main.py
import sys
from pathlib import Path

from fastapi import FastAPI
from pydantic import BaseModel

sys.path.insert(0, str(Path(__file__).parent.parent))

from src.predict import predict as run_prediction

app = FastAPI()


class PassengerFeatures(BaseModel):
    pclass: int
    sex: str
    age: float
    sibsp: int
    parch: int
    fare: float
    embarked: str


@app.post("/predict")
def predict(passenger: PassengerFeatures):
    prediction = run_prediction(passenger.model_dump())
    return {"prediction": int(prediction.iloc[0])}
