#!/usr/bin/env python3
"""Train a tiny linear regression model without external dependencies."""

from __future__ import annotations

import argparse
import json
from dataclasses import dataclass
from pathlib import Path
from typing import List


@dataclass
class LinearRegressionGD:
    weight: float = 0.0
    bias: float = 0.0

    def predict(self, x_values: List[float]) -> List[float]:
        return [self.weight * x + self.bias for x in x_values]

    def fit(self, x_values: List[float], y_values: List[float], lr: float, epochs: int) -> None:
        n = len(x_values)
        if n == 0 or n != len(y_values):
            raise ValueError("x_values and y_values must be non-empty and of equal length")

        for _ in range(epochs):
            predictions = self.predict(x_values)
            error = [predictions[i] - y_values[i] for i in range(n)]

            grad_w = (2.0 / n) * sum(error[i] * x_values[i] for i in range(n))
            grad_b = (2.0 / n) * sum(error)

            self.weight -= lr * grad_w
            self.bias -= lr * grad_b


def mse(y_true: List[float], y_pred: List[float]) -> float:
    n = len(y_true)
    return sum((y_true[i] - y_pred[i]) ** 2 for i in range(n)) / n


def generate_synthetic_training_data() -> tuple[List[float], List[float]]:
    x_values = [float(i) for i in range(1, 21)]
    base_noise_values = [-0.3, -0.2, -0.1, 0.0, 0.1, 0.2]
    noise = [base_noise_values[i % len(base_noise_values)] for i in range(len(x_values))]
    y_values = [2.0 * x + 3.0 + noise[i] for i, x in enumerate(x_values)]
    return x_values, y_values


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Train a simple linear regression model")
    parser.add_argument("--epochs", type=int, default=2000, help="Number of training epochs")
    parser.add_argument("--learning-rate", type=float, default=0.001, help="Gradient descent learning rate")
    parser.add_argument(
        "--output",
        type=Path,
        default=Path("model_artifacts/linear_regression_model.json"),
        help="Path to save the trained model artifact",
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()

    x_values, y_values = generate_synthetic_training_data()
    model = LinearRegressionGD()
    model.fit(x_values, y_values, lr=args.learning_rate, epochs=args.epochs)

    predictions = model.predict(x_values)
    train_mse = mse(y_values, predictions)

    artifact = {
        "model_type": "linear_regression_gradient_descent",
        "weight": model.weight,
        "bias": model.bias,
        "train_mse": train_mse,
        "epochs": args.epochs,
        "learning_rate": args.learning_rate,
    }

    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(artifact, indent=2), encoding="utf-8")

    print("Training complete")
    print(f"Weight: {model.weight:.4f}")
    print(f"Bias: {model.bias:.4f}")
    print(f"Train MSE: {train_mse:.6f}")
    print(f"Artifact saved to: {args.output}")


if __name__ == "__main__":
    main()
